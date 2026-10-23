# Exercise 7.2: Restore drill

`start/setup.sh` starts the pricing database `m07x2-db` on the volume `m07x2-pgdata`, with this week's
changes: Monday's tariff for `site-N03` and 25 quotes. Back it up, let `start/wreck.sh` damage it, and
restore it from your backup.

1. Start the database: `bash module-07/exercises/exercise-2/start/setup.sh`. Don't run it again
   later: that would hide the drill.
2. Back up the database into `.lab/m07x2/`, with a method from lesson 7.3.
3. Wreck it: `bash module-07/exercises/exercise-2/start/wreck.sh`
4. Restore from your backup, so that `m07x2-db` (the same container name) serves the data as it was.
   You may replace the container and its volume.
5. Check: `python -m pytest module-07/exercises/exercise-2`

The check counts the charges, the tariffs, Monday's tariff and the quotes in `m07x2-db`, and looks for
your backup in `.lab/m07x2/`. Clean up afterwards: `docker rm -f -v m07x2-db`,
`docker volume rm m07x2-pgdata`, `rm -rf .lab/m07x2`.
