# Exercise 1.1: Find the database's process

Ravi asks you to prove that the pricing database "is just a process". Start it, then find five
facts about it with the commands from lessons 1.2 and 1.3.

1. From the repository root, start the database: `bash module-01/exercises/exercise-1/start/setup.sh`
2. Copy `start/answers.toml` to `module-01/exercises/exercise-1/answers.toml` and fill it in.
3. Check: `python -m pytest module-01/exercises/exercise-1`

Clean up afterwards: `docker rm -f m01x1-db`.
