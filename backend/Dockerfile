FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends build-essential libpq-dev curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000
# В проде запускаем uvicorn без --reload — иначе процесс будет следить за
# файловой системой и крашиться при любых тачах в /app. Для разработки
# поднимайте локально или через `docker compose run --rm -v ./backend:/app
# backend uvicorn app.main:app --reload --host 0.0.0.0`.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
