# syntax=docker/dockerfile:1
# Exercise 3.1: the worker image, started through start-worker.sh. Build it from the repository root:
#   docker build -f module-03/exercises/exercise-1/Dockerfile --build-context scripts=module-03/exercises/exercise-1 -t brightlane/pricing:m03x1 app
FROM python:3.14.9-slim-trixie
WORKDIR /app
COPY . .
RUN pip install --no-cache-dir .
COPY --from=scripts --chmod=755 start-worker.sh /usr/local/bin/start-worker.sh
ENTRYPOINT start-worker.sh
