# Exercise 8.1: The stack from scratch

`start/run-stack.sh` starts a small pricing stack (database, API, proxy) the way module 6 did: with
`docker network`, `docker run` and a database script. Write `compose.yaml` in this folder
(`module-08/exercises/exercise-1/`) that starts the same stack, so that:

- the project is named `m08x1`;
- the database keeps its data in a named volume and gets the schema and the seed on its first start;
- the database and the API have healthchecks, and nothing starts before what it needs is ready;
- the proxy, with `start/nginx.conf`, is the only published port: `127.0.0.1:8781`.

1. Read `start/run-stack.sh` (you may run it to see the stack work, then remove it with the
   commands at its end).
2. Write `compose.yaml` and try it: `docker compose -f module-08/exercises/exercise-1/compose.yaml up -d --wait`
3. Check: `python -m pytest module-08/exercises/exercise-1`

The check runs `up -d --wait` itself, posts a quote to the proxy, reads every container's published
ports, then takes the stack down (without `-v`) and up again and makes sure the database kept a row
it added. Clean up afterwards: `docker compose -f module-08/exercises/exercise-1/compose.yaml down -v`.
