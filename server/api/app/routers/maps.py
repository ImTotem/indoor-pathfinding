import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dto.map_dto import MapCreateRequest, MapUpdateRequest, MapResponse
from app.models import Map
from app.repository.map_repository import MapRepository

router = APIRouter()


def get_repository(db: AsyncSession = Depends(get_db)) -> MapRepository:
    return MapRepository(db)


@router.post("/", response_model=MapResponse, status_code=201)
async def create_map(
    body: MapCreateRequest,
    repo: MapRepository = Depends(get_repository),
):
    entity = Map(**body.model_dump())
    return await repo.save(entity)


@router.get("/", response_model=list[MapResponse])
async def list_maps(
    repo: MapRepository = Depends(get_repository),
):
    return await repo.find_all()


@router.get("/{map_id}", response_model=MapResponse)
async def get_map(
    map_id: uuid.UUID,
    repo: MapRepository = Depends(get_repository),
):
    return await repo.get_by_id(map_id)


@router.put("/{map_id}", response_model=MapResponse)
async def update_map(
    map_id: uuid.UUID,
    body: MapUpdateRequest,
    repo: MapRepository = Depends(get_repository),
):
    entity = await repo.get_by_id(map_id)
    for key, value in body.model_dump(exclude_unset=True).items():
        setattr(entity, key, value)
    return await repo.save(entity)


@router.delete("/{map_id}", status_code=204)
async def delete_map(
    map_id: uuid.UUID,
    repo: MapRepository = Depends(get_repository),
):
    entity = await repo.get_by_id(map_id)
    await repo.delete(entity)
