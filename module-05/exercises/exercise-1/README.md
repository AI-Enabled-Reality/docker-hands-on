# Exercise 5.1: Pin it

The lab registry holds Monday's release, `127.0.0.1:5001/brightlane/pricing:1.0.0`, with the tariff
rulebook. Deploy it so that a re-push of `1.0.0` can't change what runs.

1. Start the registry and push Monday's release: `bash module-05/exercises/exercise-1/start/setup.sh`
2. Copy `start/answers.toml` into this folder (`module-05/exercises/exercise-1/`) and fill it in:
   the reference you deploy, pinned by digest, and the digest of the manifest for your Mac's
   platform inside it.
3. Deploy: `docker run -d --name m05x1-api <the image reference from answers.toml>`
4. Check: `python -m pytest module-05/exercises/exercise-1`

The check pushes a different image under `1.0.0` (Tuesday's mistake) and makes sure your reference
still gets Monday's. Clean up afterwards: `docker rm -f m05x1-api` and
`docker rm -f -v m05x1-registry`.
