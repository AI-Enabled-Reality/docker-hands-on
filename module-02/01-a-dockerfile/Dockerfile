# syntax=docker/dockerfile:1
# Lesson 2.1: the pricing API's first image.
# Build from the repository root, with app/ as the build context:
#   docker build -f module-02/01-a-dockerfile/Dockerfile -t brightlane/pricing:0.1 app

# Start from the official Python image: Debian 13 with Python 3.14.9.
FROM python:3.14.9-slim-trixie

# Labels are metadata: they add no layer.
LABEL org.opencontainers.image.title="Brightlane pricing service" \
      org.opencontainers.image.source="https://github.com/AI-Enabled-Reality/docker-hands-on"

# Every following instruction runs in /app (created if it doesn't exist).
WORKDIR /app

# Copy the build context (the app/ folder) into /app.
COPY . .

# Install the app and its dependencies into the image's Python.
RUN pip install --no-cache-dir .

# Documents the port the app listens on. It publishes nothing.
EXPOSE 8000

# What a container runs when you don't say otherwise.
CMD ["uvicorn", "pricing.api:app", "--host", "0.0.0.0", "--port", "8000"]
