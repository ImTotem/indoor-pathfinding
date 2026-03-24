"""MUSt3R SLAM ROS2 래퍼 노드.

gateway가 발행하는 CompressedImage 토픽을 구독하여
MUSt3R SLAM에 프레임을 전달하고 결과를 저장한다.
"""

import os
import time
import logging
import threading
from dataclasses import dataclass, field

import cv2
import numpy as np
import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy
from sensor_msgs.msg import CompressedImage

os.environ.setdefault("XFORMERS_DISABLED", "1")

from must3r.slam.model import SLAM_MUSt3R  # noqa: E402

log = logging.getLogger(__name__)


@dataclass
class SessionState:
    session_id: str
    map_id: str
    model: SLAM_MUSt3R
    frame_id: int = 0
    frames_received: int = 0
    frames_processed: int = 0
    keyframes: int = 0
    start_time: float = field(default_factory=time.time)
    status: str = "processing"  # loading → processing → saving → completed
    error_message: str | None = None
    all_pts3d: list = field(default_factory=list)  # 3D 포인트 누적
    all_colors: list = field(default_factory=list)  # 색상 누적


class MUSt3RNode(Node):
    def __init__(self):
        super().__init__("must3r_slam")
        # rclpy Jazzy 호환: _subscriptions가 dict로 초기화되는 버그 우회
        if not isinstance(getattr(self, '_subscriptions', None), list):
            self._subscriptions = []
        self.sessions: dict[str, SessionState] = {}
        self._slam_subs: dict[str, rclpy.subscription.Subscription] = {}
        self._lock = threading.Lock()

        self.chkpt = os.getenv("MUST3R_CHKPT", "/workspace/weights/MUSt3R_512.pth")
        self.res = int(os.getenv("MUST3R_RES", "512"))
        self.device = os.getenv("MUST3R_DEVICE", "cuda:0")
        self.maps_dir = os.getenv("MAPS_DIR", "/workspace/maps")

        self.get_logger().info(
            f"MUSt3R node ready (chkpt={self.chkpt}, res={self.res}, device={self.device})"
        )

    def start_session(self, session_id: str, map_id: str) -> SessionState:
        with self._lock:
            if session_id in self.sessions:
                return self.sessions[session_id]

        self.get_logger().info(f"Loading model for session {session_id}")
        model = SLAM_MUSt3R(
            chkpt=self.chkpt,
            res=self.res,
            device=self.device,
            num_init_frames=2,
        )

        state = SessionState(
            session_id=session_id,
            map_id=map_id,
            model=model,
        )

        # 전수 처리를 위한 큰 큐
        qos = QoSProfile(
            reliability=ReliabilityPolicy.BEST_EFFORT,
            history=HistoryPolicy.KEEP_ALL,
        )

        topic = f"/slam/mapping/{session_id}/image/compressed"
        with self._lock:
            self.sessions[session_id] = state

        sub = self.create_subscription(
            CompressedImage,
            topic,
            lambda msg, sid=session_id: self._on_image(sid, msg),
            qos,
        )

        with self._lock:
            self._slam_subs[session_id] = sub

        self.get_logger().info(f"Session {session_id} started, subscribing to {topic}")
        return state

    def stop_session(self, session_id: str) -> dict:
        with self._lock:
            state = self.sessions.pop(session_id, None)
            sub = self._slam_subs.pop(session_id, None)

        if sub is not None:
            self.destroy_subscription(sub)

        if state is None:
            return {"map_id": "", "completed": False}

        state.status = "saving"
        map_dir = os.path.join(self.maps_dir, state.map_id)
        os.makedirs(map_dir, exist_ok=True)

        poses_path = os.path.join(map_dir, "all_poses.npz")
        memory_path = os.path.join(map_dir, "memory.pkl")

        try:
            state.model.write_all_poses(poses_path)
            state.model.save_memory(memory_path)

            # 포인트 클라우드 저장
            if state.all_pts3d:
                all_pts = np.concatenate(state.all_pts3d, axis=0)
                all_col = np.concatenate(state.all_colors, axis=0) if state.all_colors else None
                pointcloud_path = os.path.join(map_dir, "pointcloud.npz")
                save_data = {"points": all_pts}
                if all_col is not None:
                    save_data["colors"] = all_col
                np.savez_compressed(pointcloud_path, **save_data)
                self.get_logger().info(f"Point cloud saved: {len(all_pts)} points")

            state.status = "completed"
            self.get_logger().info(
                f"Session {session_id} saved: {state.frames_processed} frames, "
                f"{state.keyframes} keyframes → {map_dir}"
            )
        except Exception as e:
            state.status = "error"
            state.error_message = str(e)
            self.get_logger().error(f"Session {session_id} save failed: {e}")

        # 모델 해제
        del state.model

        return {
            "map_id": state.map_id,
            "completed": state.status == "completed",
            "poses_path": poses_path if state.status == "completed" else None,
            "memory_path": memory_path if state.status == "completed" else None,
            "total_keyframes": state.keyframes,
        }

    def get_session_status(self, session_id: str) -> dict | None:
        with self._lock:
            state = self.sessions.get(session_id)
        if state is None:
            return None
        return {
            "session_id": state.session_id,
            "map_id": state.map_id,
            "status": state.status,
            "frames_received": state.frames_received,
            "frames_processed": state.frames_processed,
            "keyframes": state.keyframes,
            "elapsed_sec": round(time.time() - state.start_time, 1),
        }

    def list_sessions(self) -> list[dict]:
        with self._lock:
            sids = list(self.sessions.keys())
        return [self.get_session_status(sid) for sid in sids if self.get_session_status(sid)]

    def _on_image(self, session_id: str, msg: CompressedImage):
        with self._lock:
            state = self.sessions.get(session_id)
        if state is None:
            return

        state.frames_received += 1

        # JPEG 디코딩
        jpeg_data = np.frombuffer(bytes(msg.data), dtype=np.uint8)
        frame = cv2.imdecode(jpeg_data, cv2.IMREAD_COLOR)
        if frame is None:
            self.get_logger().warn(f"Failed to decode frame {state.frames_received}")
            return

        # BGR → RGB
        frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

        # MUSt3R 처리
        # result = (pts3d, colors, depth, conf, focal, w2c, HW, iskeyframe)
        try:
            result = state.model(frame, state.frame_id, cam_id=0)
            state.frame_id += 1
            state.frames_processed += 1

            # pts3d, colors 누적 (키프레임만 저장해서 메모리 절약)
            pts3d, colors = result[0], result[1]
            iskeyframe = len(result) > 7 and result[7]
            if iskeyframe:
                state.keyframes += 1
                if pts3d is not None:
                    pts = np.array(pts3d).reshape(-1, 3) if not isinstance(pts3d, np.ndarray) else pts3d.reshape(-1, 3)
                    state.all_pts3d.append(pts)
                if colors is not None:
                    col = np.array(colors).reshape(-1, 3) if not isinstance(colors, np.ndarray) else colors.reshape(-1, 3)
                    state.all_colors.append(col)
        except Exception as e:
            self.get_logger().error(f"MUSt3R inference error: {e}")
