# syntax=docker/dockerfile:1
# Exercise 7.1: the pricing image as it is today: it runs as root.
#   docker build -f module-07/exercises/exercise-1/Dockerfile -t brightlane/pricing:m07x1 app

# ---- Stage 1, build: Python, uv, and everything it takes to make the virtual environment.
FROM python:3.14.9-slim-trixie AS build
COPY --from=ghcr.io/astral-sh/uv:0.13.5 /uv /bin/uv
# Compile bytecode now, not at every start; copy files out of uv's cache rather than linking
# them; use this image's Python, never download one; leave out the dev dependency group.
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy UV_PYTHON_DOWNLOADS=0 UV_NO_DEV=1
WORKDIR /app
# The dependencies alone, from the lock file. The cache mount keeps uv's downloads between builds;
# the bind mounts read the two files without copying them into a layer.
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project
# Then the project itself, installed into the environment like any package (not linked to src/).
COPY . .
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-editable

# ---- Stage 2, runtime: the same Python, the environment, nothing else.
FROM python:3.14.9-slim-trixie
LABEL org.opencontainers.image.title="Brightlane pricing service" \
      org.opencontainers.image.source="https://github.com/AI-Enabled-Reality/docker-hands-on"
WORKDIR /app
COPY --from=build /app/.venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH" PYTHONUNBUFFERED=1
EXPOSE 8000
ENTRYPOINT ["pricing"]
CMD ["api"]
