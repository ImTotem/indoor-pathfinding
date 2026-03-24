"""MUSt3R SLAM 내부 HTTP API.

API 서버(server/api/)의 MUSt3RService가 이 API를 호출한다.
ROS2 노드와 같은 프로세스에서 실행되며, 노드의 세션 관리 메서드를 호출.
"""

import os
import struct
import subprocess
import threading
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from pathlib import Path

import rclpy
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from .node import MUSt3RNode


class StartRequest(BaseModel):
    session_id: str
    map_id: str


# 글로벌 노드 (lifespan에서 초기화)
_node: MUSt3RNode | None = None
_spin_thread: threading.Thread | None = None


def _spin_node():
    """ROS2 노드를 별도 스레드에서 spin."""
    global _node
    if _node is not None:
        rclpy.spin(_node)


@asynccontextmanager
async def lifespan(app: FastAPI):
    global _node, _spin_thread
    rclpy.init()
    _node = MUSt3RNode()
    _spin_thread = threading.Thread(target=_spin_node, daemon=True)
    _spin_thread.start()
    yield
    _node.destroy_node()
    rclpy.shutdown()


app = FastAPI(title="MUSt3R SLAM Internal API", lifespan=lifespan)


@app.get("/health")
async def health():
    return {"status": "ok"}


# ── 세션 ──


@app.post("/sessions", status_code=201)
async def start_session(body: StartRequest):
    state = _node.start_session(body.session_id, body.map_id)
    return _node.get_session_status(state.session_id)


@app.get("/sessions")
async def list_sessions():
    return _node.list_sessions()


@app.get("/sessions/{session_id}")
async def get_session(session_id: str):
    status = _node.get_session_status(session_id)
    if status is None:
        raise HTTPException(404, f"Session not found: {session_id}")
    return status


@app.delete("/sessions/{session_id}")
async def stop_session(session_id: str):
    result = _node.stop_session(session_id)
    if not result["map_id"]:
        raise HTTPException(404, f"Session not found: {session_id}")
    return result


# ── 맵 ──


@app.get("/maps")
async def list_maps():
    maps_dir = os.getenv("MAPS_DIR", "/workspace/maps")
    results = []
    if not os.path.isdir(maps_dir):
        return results
    for map_id in os.listdir(maps_dir):
        map_path = Path(maps_dir) / map_id
        if not map_path.is_dir():
            continue
        poses = map_path / "all_poses.npz"
        memory = map_path / "memory.pkl"
        results.append({
            "map_id": map_id,
            "completed": poses.exists() and memory.exists(),
            "poses_path": str(poses) if poses.exists() else None,
            "memory_path": str(memory) if memory.exists() else None,
            "total_keyframes": 0,  # npz 열어야 알 수 있음
            "created_at": datetime.fromtimestamp(
                poses.stat().st_mtime, tz=timezone.utc
            ).isoformat() if poses.exists() else None,
        })
    return results


@app.get("/maps/{map_id}")
async def get_map(map_id: str):
    maps_dir = os.getenv("MAPS_DIR", "/workspace/maps")
    map_path = Path(maps_dir) / map_id
    if not map_path.is_dir():
        raise HTTPException(404, f"Map not found: {map_id}")
    poses = map_path / "all_poses.npz"
    memory = map_path / "memory.pkl"
    return {
        "map_id": map_id,
        "completed": poses.exists() and memory.exists(),
        "poses_path": str(poses) if poses.exists() else None,
        "memory_path": str(memory) if memory.exists() else None,
        "total_keyframes": 0,
        "created_at": datetime.fromtimestamp(
            poses.stat().st_mtime, tz=timezone.utc
        ).isoformat() if poses.exists() else None,
    }


# ── 시각화 ──


def _extract_images_from_mcap(session_id: str, out_dir: Path) -> int:
    """mcap rosbag2에서 JPEG 이미지 추출"""
    from mcap.reader import make_reader

    rosbag_dir = Path("/workspace/rosbag2") / session_id
    mcap_files = list(rosbag_dir.glob("*.mcap"))
    if not mcap_files:
        return 0

    out_dir.mkdir(parents=True, exist_ok=True)
    count = 0
    for mcap_file in mcap_files:
        with open(mcap_file, "rb") as f:
            reader = make_reader(f)
            for schema, channel, message in reader.iter_messages():
                if "CompressedImage" not in schema.name:
                    continue
                # CDR에서 JPEG 시그니처 위치 찾기
                data = message.data
                hx = data.hex()
                idx = hx.find("ffd8ff")
                if idx < 0:
                    continue
                jpeg = bytes.fromhex(hx[idx:])
                (out_dir / f"frame_{count:05d}.jpeg").write_bytes(jpeg)
                count += 1
    return count


_viser_server = None


@app.post("/maps/{map_id}/visualize")
async def visualize_map(map_id: str, port: int = 7860):
    """저장된 맵을 viser로 시각화. 브라우저에서 http://host:{port} 접속."""
    global _viser_server
    import numpy as np
    import viser

    maps_dir = os.getenv("MAPS_DIR", "/workspace/maps")
    map_path = Path(maps_dir) / map_id
    poses_path = map_path / "all_poses.npz"
    pointcloud_path = map_path / "pointcloud.npz"

    if not poses_path.exists():
        raise HTTPException(404, f"Map poses not found: {map_id}")

    # 포즈 로드
    data = np.load(str(poses_path), allow_pickle=True)
    poses = data["poses"]  # (N, 4, 4)
    positions = poses[:, :3, 3]  # (N, 3) 카메라 위치

    # 포인트 클라우드 로드
    pts3d = None
    colors = None
    if pointcloud_path.exists():
        pc_data = np.load(str(pointcloud_path), allow_pickle=True)
        pts3d = pc_data["points"] if "points" in pc_data else None
        colors = pc_data["colors"] if "colors" in pc_data else None

    # 이전 서버 종료
    if _viser_server is not None:
        try:
            _viser_server.stop()
        except Exception:
            try:
                _viser_server.close()
            except Exception:
                pass
        _viser_server = None

    # viser 서버 시작
    server = viser.ViserServer(host="0.0.0.0", port=port)
    _viser_server = server

    # 카메라 궤적 (녹색 점)
    scale = 100.0  # MUSt3R 스케일이 매우 작음
    server.scene.add_point_cloud(
        "camera_trajectory",
        points=(positions * scale).astype(np.float32),
        colors=np.tile([0, 255, 0], (len(positions), 1)).astype(np.uint8),
        point_size=0.08,
    )

    # 3D 포인트 클라우드 (흰색 점)
    if pts3d is not None and len(pts3d) > 0:
        if colors is None:
            colors = np.tile([200, 200, 200], (len(pts3d), 1)).astype(np.uint8)
        server.scene.add_point_cloud(
            "point_cloud",
            points=(pts3d * scale).astype(np.float32),
            colors=colors,
            point_size=0.02,
        )

    return {
        "map_id": map_id,
        "status": "visualizing",
        "poses": len(positions),
        "points": len(pts3d) if pts3d is not None else 0,
        "url": f"http://localhost:{port}",
    }
