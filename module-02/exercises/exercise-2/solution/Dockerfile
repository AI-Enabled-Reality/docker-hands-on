# syntax=docker/dockerfile:1
# Exercise 2.2, a solution. Build it from the repository root:
#   docker build -f module-02/exercises/exercise-2/solution/Dockerfile -t brightlane/pricing:m02x2 app
FROM python:3.14.9-slim-trixie
WORKDIR /app
COPY . .
RUN pip install --no-cache-dir .
EXPOSE 8000
ENTRYPOINT ["pricing"]
CMD ["api"]
