import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import Map

router = APIRouter()


class MapCreate(BaseModel):
    name: str
    description: str | None = None
    metadata_json: dict | None = None


class MapResponse(BaseModel):
    id: uuid.UUID
    name: str
    description: str | None
    metadata_json: dict | None

    model_config = {"from_attributes": True}


@router.post("/", response_model=MapResponse, status_code=201)
async def create_map(body: MapCreate, db: AsyncSession = Depends(get_db)):
    m = Map(**body.model_dump())
    db.add(m)
    await db.commit()
    await db.refresh(m)
    return m


@router.get("/", response_model=list[MapResponse])
async def list_maps(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Map).order_by(Map.created_at.desc()))
    return result.scalars().all()


@router.get("/{map_id}", response_model=MapResponse)
async def get_map(map_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    m = await db.get(Map, map_id)
    if not m:
        raise HTTPException(status_code=404, detail="Map not found")
    return m


@router.delete("/{map_id}", status_code=204)
async def delete_map(map_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    m = await db.get(Map, map_id)
    if not m:
        raise HTTPException(status_code=404, detail="Map not found")
    await db.delete(m)
    await db.commit()
