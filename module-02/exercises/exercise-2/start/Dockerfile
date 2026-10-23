# syntax=docker/dockerfile:1
# Exercise 2.2: make this image run every program of the pricing service. Build it with:
#   docker build -f module-02/exercises/exercise-2/Dockerfile -t brightlane/pricing:m02x2 app
FROM python:3.14.9-slim-trixie
WORKDIR /app
COPY . .
RUN pip install --no-cache-dir .
EXPOSE 8000
CMD ["uvicorn", "pricing.api:app", "--host", "0.0.0.0", "--port", "8000"]
