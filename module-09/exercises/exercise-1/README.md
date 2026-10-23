# Exercise 9.1: A fast dev loop

`compose.yaml` in this folder is lesson 9.1's stack as project `m09x1`, with the proxy on
`127.0.0.1:8792`. `start/compose.override.yaml` is a colleague's first attempt at a development setup:
a bind mount of the whole project. Copy it next to `compose.yaml` and rewrite it so that, with
`docker compose up --watch` in this folder:

- the API is published directly on `127.0.0.1:8791`;
- an edit to `app/src/pricing/api.py` is answered by the running API within 5 seconds, by the **same**
  container;
- a change to `app/pyproject.toml` or `app/uv.lock` builds the image again and replaces the container.

Check: `python -m pytest module-09/exercises/exercise-1`. The check starts `docker compose up --watch`
in this folder itself, edits `api.py` and `pyproject.toml` (and puts both back), and compares the API's
container ID before and after. Clean up afterwards:
`docker compose -f module-09/exercises/exercise-1/compose.yaml -f module-09/exercises/exercise-1/compose.override.yaml down -v`.
