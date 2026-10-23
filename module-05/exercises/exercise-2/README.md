# Exercise 5.2: Both platforms, warm cache

`start/build.sh` builds the pricing image for your Mac only, pushes it as
`127.0.0.1:5001/brightlane/pricing:1.2.0`, and leaves no cache that a CI runner could use. Change it
so that it:

- pushes `1.2.0` as one index with a `linux/arm64` and a `linux/amd64` image;
- exports the build cache to `127.0.0.1:5001/brightlane/pricing:buildcache`, complete enough that,
  after a code change, a new, empty builder doesn't install the dependencies again
  (`uv sync --locked --no-install-project`) for either platform.

1. Copy `start/build.sh` into this folder (`module-05/exercises/exercise-2/`) and change it.
2. Check: `python -m pytest module-05/exercises/exercise-2`

The check starts its own registry, `m05x2-registry`, on port 5001 (it removes the lesson and
exercise 1 registries if they're still running), runs your `build.sh` and reads the index. Then it
changes one line of code in a scratch copy of `app/` and builds that in a new `docker-container`
builder with `--cache-from`, and reads which `uv sync` steps ran.
Behind a TLS-intercepting proxy, set `LAB_BUILDKIT_IMAGE` as in lesson 5.3. Clean up afterwards:
`docker rm -f -v m05x2-registry`.
