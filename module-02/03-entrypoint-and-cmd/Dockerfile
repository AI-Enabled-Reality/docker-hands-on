# syntax=docker/dockerfile:1
# Lesson 2.3: one image for the API and the worker.
#   docker build -f module-02/03-entrypoint-and-cmd/Dockerfile -t brightlane/pricing:0.3 app
FROM python:3.14.9-slim-trixie
LABEL org.opencontainers.image.title="Brightlane pricing service" \
      org.opencontainers.image.source="https://github.com/AI-Enabled-Reality/docker-hands-on"
WORKDIR /app
COPY . .
RUN pip install --no-cache-dir .
EXPOSE 8000

# The program: always `pricing`. Arguments to `docker run` are appended to it.
ENTRYPOINT ["pricing"]
# The default arguments: `pricing api`. Any arguments to `docker run` replace them.
CMD ["api"]
