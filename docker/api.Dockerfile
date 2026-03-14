FROM python:3.12-slim

WORKDIR /app

COPY server/api/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY server/api/app ./app
COPY server/db/ ./db/

EXPOSE 8000

# alembic 마이그레이션 후 서버 시작
CMD ["sh", "-c", "cd db && alembic upgrade head && cd /app && uvicorn app.main:app --host 0.0.0.0 --port 8000"]
