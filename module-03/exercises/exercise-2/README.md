# Exercise 3.2: Post-mortem

Three containers died overnight. Find out why each one stopped, from what Docker kept about it.

1. Create the three dead containers: `bash module-03/exercises/exercise-2/start/setup.sh`
2. Copy `start/answers.toml` into this folder (`module-03/exercises/exercise-2/`) and fill it in.
3. Check: `python -m pytest module-03/exercises/exercise-2`

Clean up afterwards: `docker rm -f m03x2-a m03x2-b m03x2-c`.
