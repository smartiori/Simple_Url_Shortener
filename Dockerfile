FROM python:3.9-slim

LABEL maintainer="ShortURL Service"
LABEL description="Flask based URL Shortener Service"

ENV PYTHONUNBUFFERED=1
ENV FLASK_APP=app.py
ENV FLASK_ENV=production

WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir gunicorn

COPY . .

RUN mkdir -p /app/data

EXPOSE 5000

CMD ["sh", "-c", "python -c \"from app import init_db; init_db()\" && exec gunicorn --bind 0.0.0.0:5000 --workers 2 --threads 4 app:app"]
