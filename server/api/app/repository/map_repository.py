import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.exceptions import EntityNotFoundException
from app.models import Map


class MapRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def save(self, entity: Map) -> Map:
        self.db.add(entity)
        await self.db.commit()
        await self.db.refresh(entity)
        return entity

    async def find_all(self) -> list[Map]:
        result = await self.db.execute(select(Map).order_by(Map.created_at.desc()))
        return list(result.scalars().all())

    async def find_by_id(self, map_id: uuid.UUID) -> Map | None:
        return await self.db.get(Map, map_id)

    async def get_by_id(self, map_id: uuid.UUID) -> Map:
        entity = await self.find_by_id(map_id)
        if not entity:
            raise EntityNotFoundException("Map", map_id)
        return entity

    async def delete(self, entity: Map) -> None:
        await self.db.delete(entity)
        await self.db.commit()
