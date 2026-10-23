# Exercise 1.2: Where did the disk go?

Tomasz ran two experiments in containers and wants to know what they cost on disk. Account
for every megabyte with the commands from lesson 1.4.

1. From the repository root, create the two containers: `bash module-01/exercises/exercise-2/start/setup.sh`
2. Copy `start/answers.toml` to `module-01/exercises/exercise-2/answers.toml` and fill it in.
3. Check: `python -m pytest module-01/exercises/exercise-2`

Clean up afterwards: `docker rm -f m01x2-export m01x2-trim`.
