# syntax=docker/dockerfile:1
# Exercise 4.1: the contractor's Dockerfile. Make it small and fast. Build it from the repository root:
#   docker build -f module-04/exercises/exercise-1/Dockerfile -t brightlane/pricing:m04x1 app
FROM python:3.14.9-slim-trixie
WORKDIR /app
COPY . .
RUN pip install uv && uv pip install --system -r requirements.txt && pip install .
EXPOSE 8000
ENTRYPOINT ["pricing"]
CMD ["api"]
