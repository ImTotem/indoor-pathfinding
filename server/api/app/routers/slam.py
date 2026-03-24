from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dto.slam_dto import (
    MapResultResponse,
    SessionResponse,
    StartSessionRequest,
)
from app.repository.map_repository import MapRepository
from app.services.must3r_service import MUSt3RService
from app.services.slam_service import SlamServiceBase

router = APIRouter()

_slam_service: SlamServiceBase | None = None


def get_slam_service() -> SlamServiceBase:
    global _slam_service
    if _slam_service is None:
        _slam_service = MUSt3RService()
    return _slam_service


def get_repository(db: AsyncSession = Depends(get_db)) -> MapRepository:
    return MapRepository(db)


# ── 세션 (녹화 중) ──


@router.post("/sessions", response_model=SessionResponse, status_code=201)
async def start_session(
    body: StartSessionRequest,
    slam: SlamServiceBase = Depends(get_slam_service),
):
    return await slam.start_session(body.session_id, body.map_id)


@router.get("/sessions", response_model=list[SessionResponse])
async def list_sessions(
    slam: SlamServiceBase = Depends(get_slam_service),
):
    return await slam.list_sessions()


@router.get("/sessions/{session_id}", response_model=SessionResponse)
async def get_session_status(
    session_id: str,
    slam: SlamServiceBase = Depends(get_slam_service),
):
    return await slam.get_session_status(session_id)


@router.delete("/sessions/{session_id}", response_model=MapResultResponse)
async def stop_session(
    session_id: str,
    slam: SlamServiceBase = Depends(get_slam_service),
    repo: MapRepository = Depends(get_repository),
):
    result = await slam.stop_session(session_id)

    # DB에 SLAM 결과 반영
    if result.completed and result.map_id:
        try:
            import uuid as _uuid
            entity = await repo.find_by_id(_uuid.UUID(result.map_id))
            if entity:
                entity.slam_completed = True
                entity.slam_keyframes = result.total_keyframes
                await repo.save(entity)
        except Exception:
            pass  # DB 업데이트 실패해도 SLAM 결과는 반환

    return result


# ── 맵 (완성된 결과물) ──


@router.get("/maps", response_model=list[MapResultResponse])
async def list_maps(
    slam: SlamServiceBase = Depends(get_slam_service),
):
    return await slam.list_maps()


@router.get("/maps/{map_id}", response_model=MapResultResponse)
async def get_map(
    map_id: str,
    slam: SlamServiceBase = Depends(get_slam_service),
):
    return await slam.get_map(map_id)
