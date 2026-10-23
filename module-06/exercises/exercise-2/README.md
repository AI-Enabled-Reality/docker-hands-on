# Exercise 6.2: The 502 hunt

`start/plant.sh` deploys the pricing database, the API and the proxy, with three faults that
aren't lesson 6.3's. The proxy answers `502 Bad Gateway` on `127.0.0.1:8762`. Find the faults with
lesson 6.3's ladder and fix them, until a quote through the proxy works.

1. Deploy: `bash module-06/exercises/exercise-2/start/plant.sh`. It copies the proxy's and the API's
   settings into `.lab/m06x2/`: change those copies, not the files in `start/`.
2. Fix what's wrong. You may recreate any of the three containers (keep their names:
   `m06x2-proxy`, `m06x2-api`, `m06x2-db`); the proxy must stay the only published entry point, on
   `127.0.0.1:8762`.
3. Check: `python -m pytest module-06/exercises/exercise-2`

Write down each fault and the rung where you found it: the solution compares notes. Clean up
afterwards: `docker rm -f -v m06x2-proxy m06x2-api m06x2-db` and
`docker network rm m06x2-front m06x2-back`.
