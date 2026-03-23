import os

import httpx

from app.dto.slam_dto import MapResultResponse, SessionResponse, SessionStatus
from app.services.slam_service import SlamServiceBase


class MUSt3RService(SlamServiceBase):
    """MUSt3R SLAM 구현체. MUSt3R Docker 컨테이너의 내부 HTTP API와 통신."""

    def __init__(self, base_url: str | None = None):
        self.base_url = base_url or os.getenv(
            "SLAM_API_URL", "http://slam:8000"
        )
        self.client = httpx.AsyncClient(base_url=self.base_url, timeout=30.0)

    async def start_session(self, session_id: str, map_id: str) -> SessionResponse:
        resp = await self.client.post(
            "/sessions",
            json={"session_id": session_id, "map_id": map_id},
        )
        resp.raise_for_status()
        return SessionResponse(**resp.json())

    async def stop_session(self, session_id: str) -> MapResultResponse:
        resp = await self.client.delete(f"/sessions/{session_id}")
        resp.raise_for_status()
        return MapResultResponse(**resp.json())

    async def get_session_status(self, session_id: str) -> SessionResponse:
        resp = await self.client.get(f"/sessions/{session_id}")
        resp.raise_for_status()
        return SessionResponse(**resp.json())

    async def list_sessions(self) -> list[SessionResponse]:
        resp = await self.client.get("/sessions")
        resp.raise_for_status()
        return [SessionResponse(**s) for s in resp.json()]

    async def get_map(self, map_id: str) -> MapResultResponse:
        resp = await self.client.get(f"/maps/{map_id}")
        resp.raise_for_status()
        return MapResultResponse(**resp.json())

    async def list_maps(self) -> list[MapResultResponse]:
        resp = await self.client.get("/maps")
        resp.raise_for_status()
        return [MapResultResponse(**m) for m in resp.json()]
