# Exercise 2.1: Containerize it yourself

Write the pricing API's Dockerfile and its ignore file from a skeleton, without looking at the
lesson's.

1. Copy `start/Dockerfile` and `start/Dockerfile.dockerignore` into this folder
   (`module-02/exercises/exercise-1/`) and fill in every TODO.
2. Build: `docker build -f module-02/exercises/exercise-1/Dockerfile -t brightlane/pricing:m02x1 app`
3. Check: `python -m pytest module-02/exercises/exercise-1`

The check plants an `app/.env` and an `app/.venv` while it builds (and removes them afterwards),
starts your image on `127.0.0.1:8711`, and looks inside it.
