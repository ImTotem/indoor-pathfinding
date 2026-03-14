from fastapi import FastAPI

from app.routers import maps

app = FastAPI(
    title="Indoor Pathfinding API",
    version="0.1.0",
)

app.include_router(maps.router, prefix="/api/maps", tags=["maps"])


@app.get("/health")
async def health():
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
