"""MUSt3R SLAM 내부 HTTP API.

API 서버(server/api/)의 MUSt3RService가 이 API를 호출한다.
ROS2 노드와 같은 프로세스에서 실행되며, 노드의 세션 관리 메서드를 호출.
"""

import os
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
