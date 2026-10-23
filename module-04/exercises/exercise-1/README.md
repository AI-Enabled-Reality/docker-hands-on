# Exercise 4.1: Small and fast

`start/Dockerfile` is the pricing image as a contractor left it: one stage, everything copied
first, installed with pip. Turn it into a multi-stage build with uv, like lesson 4.2's, so that:

- the runtime image holds no uv, no source folder (`/app/src`) and no pip or uv cache;
- a code change doesn't reinstall the dependencies: the `uv sync … --no-install-project` step stays
  `CACHED`;
- `docker run brightlane/pricing:m04x1 version` still works.

1. Copy `start/Dockerfile` and `start/Dockerfile.dockerignore` into this folder
   (`module-04/exercises/exercise-1/`) and rewrite the Dockerfile.
2. Build: `docker build -f module-04/exercises/exercise-1/Dockerfile -t brightlane/pricing:m04x1 app`
3. Check: `python -m pytest module-04/exercises/exercise-1` (it builds twice, the second time after
   changing a line of code in a scratch copy of `app/`).
