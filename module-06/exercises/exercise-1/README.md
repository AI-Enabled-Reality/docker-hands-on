# Exercise 6.1: The right network

`start/run-api.sh` starts the pricing API against the database that `start/setup.sh` runs, the way
it was done before this module: on the default bridge, by IP address, published on every interface.
Rewrite it so that:

- the API finds the database by name, on a network you create;
- the API is published on `127.0.0.1:8761` only;
- both survive a restart in any order.

1. Start the database: `bash module-06/exercises/exercise-1/start/setup.sh`
2. Copy `start/run-api.sh` into this folder (`module-06/exercises/exercise-1/`), change it, and run it:
   `bash module-06/exercises/exercise-1/run-api.sh`. It may also create networks and change the
   database container, as long as the database container stays `m06x1-db`.
3. Check: `python -m pytest module-06/exercises/exercise-1`

The check runs `setup.sh` and your `run-api.sh` itself, so it starts from the same state as you.
Clean up afterwards: `docker rm -f -v m06x1-api m06x1-db` and remove your network.
