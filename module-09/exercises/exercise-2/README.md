# Exercise 9.2: Password out of the environment

`start/compose.yaml` is the pricing stack as project `m09x2`, proxy on `127.0.0.1:8793`. Four services
get the database password in their environment. Copy the file into this folder
(`module-09/exercises/exercise-2/`) and change it so that no container of the project has a password in
its environment, the stack still starts healthy, and a quote through the proxy works.

- Generate the password into a file outside Git's reach, for example
  `python3 -c 'import secrets; print(secrets.token_urlsafe(18))' > .lab/m09x2/db_password.txt`.
- Every service that needs the password gets it as a Compose secret, at `/run/secrets/…`.
- Variables named `…_FILE` that point to the file are fine; any other variable with `PASSWORD` in its
  name is not.

If the database's volume already exists with the old password, PostgreSQL keeps that one: run
`docker compose -f module-09/exercises/exercise-2/compose.yaml down -v` before the first `up` with the
secret.

Check: `python -m pytest module-09/exercises/exercise-2`. The check runs `up -d --wait`, reads every
container's environment and mounts with `docker inspect`, searches `docker compose config` for the old
password, and posts a quote. Clean up afterwards: `docker compose -f … down -v`.
