from datetime import datetime
from enum import Enum

from pydantic import BaseModel


class SessionStatus(str, Enum):
    idle = "idle"
    loading = "loading"
    processing = "processing"
    saving = "saving"
    completed = "completed"
    error = "error"


class StartSessionRequest(BaseModel):
    session_id: str
    map_id: str


class SessionResponse(BaseModel):
    session_id: str
    map_id: str
    status: SessionStatus
    frames_received: int = 0
    frames_processed: int = 0
    keyframes: int = 0
    elapsed_sec: float = 0.0
    error_message: str | None = None


class MapResultResponse(BaseModel):
    map_id: str
    completed: bool
    poses_path: str | None = None
    memory_path: str | None = None
    total_keyframes: int = 0
    created_at: datetime | None = None
