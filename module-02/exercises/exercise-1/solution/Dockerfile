# syntax=docker/dockerfile:1
# Exercise 2.1, a solution. Build it from the repository root:
#   docker build -f module-02/exercises/exercise-1/solution/Dockerfile -t brightlane/pricing:m02x1 app
FROM python:3.14.9-slim-trixie
WORKDIR /app
COPY . .
RUN pip install --no-cache-dir .
EXPOSE 8000
CMD ["uvicorn", "pricing.api:app", "--host", "0.0.0.0", "--port", "8000"]
