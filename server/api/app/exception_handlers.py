from fastapi import FastAPI
from fastapi.responses import JSONResponse

from app.exceptions import EntityNotFoundException


def register_exception_handlers(app: FastAPI):
    @app.exception_handler(EntityNotFoundException)
    async def entity_not_found_handler(request, exc: EntityNotFoundException):
        return JSONResponse(status_code=404, content={"detail": str(exc)})
