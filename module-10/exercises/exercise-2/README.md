# Exercise 10.2: Know what you ship

Build the pricing image (`app/`) with an SBOM and provenance and push it to the lab registry as
`127.0.0.1:5001/brightlane/pricing:m10x2`. Start the registry first, from the repository root:

```bash
docker compose --profile registry up -d --wait
```

Then copy `start/answers.toml` into this folder (`module-10/exercises/exercise-2/`) and fill it in from
the image's SBOM: read it from the registry, not by running the image. `tools/sbom_query.py` (lesson
10.2) helps.

Check: `python -m pytest module-10/exercises/exercise-2`. The check reads the image's attestations from
the registry and compares your answers with the SBOM. Clean up afterwards:
`docker compose --profile registry down -v` and `docker image rm 127.0.0.1:5001/brightlane/pricing:m10x2`.
