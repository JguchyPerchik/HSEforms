# Минимальный образ для long-polling бота. HTTP-сервер ему не нужен:
# наружу он ничего не публикует, разговаривает только с Telegram Bot API.
FROM python:3.12-slim

WORKDIR /app

# Сначала requirements — слой с зависимостями кешируется отдельно и не
# пересобирается при правках кода бота.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# unbuffered, чтобы логи aiogram падали в `docker compose logs` сразу,
# а не зависали в буфере stdout.
ENV PYTHONUNBUFFERED=1

CMD ["python", "main.py"]
