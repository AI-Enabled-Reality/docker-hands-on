# Exercise 3.1: A worker that stops in under 2 seconds

Ravi's deploys wait for every worker to stop. The worker image below starts through a script,
and `docker stop` always takes the whole grace period. Make it stop in under 2 seconds, with
exit code 0, without changing the Python code or adding `--init`.

1. Copy `start/Dockerfile`, `start/Dockerfile.dockerignore` and `start/start-worker.sh` into this
   folder (`module-03/exercises/exercise-1/`) and fix them.
2. Build: `docker build -f module-03/exercises/exercise-1/Dockerfile --build-context scripts=module-03/exercises/exercise-1 -t brightlane/pricing:m03x1 app`
3. Check: `python -m pytest module-03/exercises/exercise-1` (it starts a database and an idle
   worker, then stops the worker).
