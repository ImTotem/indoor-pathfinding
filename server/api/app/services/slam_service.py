from abc import ABC, abstractmethod

from app.dto.slam_dto import MapResultResponse, SessionResponse


class SlamServiceBase(ABC):
    """SLAM 엔진 추상 인터페이스. 엔진 교체 시 이 클래스를 구현."""

    @abstractmethod
    async def start_session(self, session_id: str, map_id: str) -> SessionResponse:
        """세션 시작 — 모델 로드 + ROS2 토픽 구독."""
        ...

    @abstractmethod
    async def stop_session(self, session_id: str) -> MapResultResponse:
        """세션 종료 — 결과를 map_id로 저장 + 모델 해제."""
        ...

    @abstractmethod
    async def get_session_status(self, session_id: str) -> SessionResponse:
        """세션 처리 상태 조회 (진행률, 프레임 수 등)."""
        ...

    @abstractmethod
    async def list_sessions(self) -> list[SessionResponse]:
        """활성 세션 목록."""
        ...

    @abstractmethod
    async def get_map(self, map_id: str) -> MapResultResponse:
        """완성된 맵 결과 조회."""
        ...

    @abstractmethod
    async def list_maps(self) -> list[MapResultResponse]:
        """완성된 맵 목록."""
        ...
