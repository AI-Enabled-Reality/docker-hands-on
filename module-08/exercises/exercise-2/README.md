# Exercise 8.2: An ops job

Ravi wants a database backup he can run on demand on the staging server, with the stack's own tools,
and that never runs by accident. Copy `start/compose.yaml` (lesson 8.2's stack, as project `m08x2`)
into this folder (`module-08/exercises/exercise-2/`) and add a service `backup` that:

- belongs to the profile `ops`, so `docker compose up` doesn't start it;
- waits until the database is healthy;
- writes one `pg_dump -Fc` file per run into `.lab/m08x2/` (in the repository), with the date and time
  in its name, and exits with code 0.

Run it with `docker compose -f module-08/exercises/exercise-2/compose.yaml run --rm backup`.

Check: `python -m pytest module-08/exercises/exercise-2`. The check starts the stack, makes sure no
backup container was created, runs the job, and reads the new file with `pg_restore --list`. Clean up
afterwards: `docker compose -f module-08/exercises/exercise-2/compose.yaml down -v` and
`rm -rf .lab/m08x2`.
