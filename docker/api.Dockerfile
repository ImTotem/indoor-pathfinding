FROM python:3.14-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/

WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

COPY server/api/app ./app
COPY server/db/ ./db/

EXPOSE 8000

CMD ["sh", "-c", "cd db && uv run alembic upgrade head && cd /app && uv run uvicorn app.main:app --host 0.0.0.0 --port 8000"]
