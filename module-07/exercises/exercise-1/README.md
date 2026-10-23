# Exercise 7.1: Exports that survive

`start/Dockerfile` builds the pricing image the way module 4 left it: the service runs as root.
Change it so that:

- the service runs as a user that isn't root;
- the statement worker can write its exports to `/exports` on a **new, empty** named volume, with no
  `chown` or other preparation of the volume;
- the exports stay in the volume after the worker's container is gone.

1. Copy `start/Dockerfile` into this folder (`module-07/exercises/exercise-1/`) and change it.
2. Try it: `bash module-07/exercises/exercise-1/start/try.sh` builds your Dockerfile, starts a
   database, and runs one export into a new volume.
3. Check: `python -m pytest module-07/exercises/exercise-1`

The check builds your Dockerfile as `brightlane/pricing:m07x1`, runs two exports in two containers
into one new volume, and reads the volume with a third. Clean up afterwards:
`docker rm -f -v m07x1-db`, `docker network rm m07x1-net`.
