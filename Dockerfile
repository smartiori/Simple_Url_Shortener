FROM python:3.9-slim

LABEL maintainer="shorturl-app"
LABEL description="URL Shortener Flask Application"

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV FLASK_APP=app.py
ENV FLASK_ENV=production
ENV PYTHONUNBUFFERED=1
ENV DATABASE_PATH=/app/data/urls.db

EXPOSE 5000

CMD ["python", "app.py"]
