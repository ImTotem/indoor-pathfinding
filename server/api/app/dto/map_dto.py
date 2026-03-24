import uuid
from datetime import datetime

from pydantic import BaseModel


class MapCreateRequest(BaseModel):
    name: str
    description: str | None = None
    latitude: float | None = None
    longitude: float | None = None


class MapUpdateRequest(BaseModel):
    description: str | None = None
    latitude: float | None = None
    longitude: float | None = None


class MapResponse(BaseModel):
    id: uuid.UUID
    name: str
    description: str | None
    latitude: float | None
    longitude: float | None
    created_at: datetime
    slam_completed: bool = False
    slam_keyframes: int | None = None
    slam_frames: int | None = None

    model_config = {"from_attributes": True}
