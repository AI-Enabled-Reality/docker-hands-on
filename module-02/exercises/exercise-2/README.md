# Exercise 2.2: Three commands, one image

`start/Dockerfile` builds an image that can only run Uvicorn. Change it so that one image runs
every program of the pricing service:

- `docker run brightlane/pricing:m02x2` starts the API;
- `docker run brightlane/pricing:m02x2 version` prints the version as JSON;
- `docker run brightlane/pricing:m02x2 worker --once` runs one cycle of the statement worker;
- `docker run brightlane/pricing:m02x2 --help` prints the `pricing` command's help.

1. Copy `start/Dockerfile` and `start/Dockerfile.dockerignore` into this folder
   (`module-02/exercises/exercise-2/`) and change the Dockerfile.
2. Build: `docker build -f module-02/exercises/exercise-2/Dockerfile -t brightlane/pricing:m02x2 app`
3. Check: `python -m pytest module-02/exercises/exercise-2`
