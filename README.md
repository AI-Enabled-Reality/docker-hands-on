# Docker, Hands-On: the lab

The code for the course **Docker, Hands-On** on AER Academy. You containerize Brightlane
Charging's pricing service step by step, from a bare `docker run` to a production-ready Compose
stack. Every lesson's practical is a shell session in `module-NN/`; the exercises come with
automated checks.

## 1. What you need

- **macOS** on Apple Silicon or Intel. Linux works as is; on Windows, use WSL2 and run every
  command inside the Linux distribution.
- **Docker Desktop 4.96** or later (Engine 29.9, Compose 5.6, Buildx 0.38). OrbStack and Colima
  work for most lessons; where they differ, the lesson says so.
- **Memory for Docker: 4 GB or more** (Docker Desktop → Settings → Resources → Memory). The whole
  lab uses less than 1 GB while it runs; builds need more for a minute.
- **Disk:** about 6 GB for images and build cache.
- **Python 3.11 or later** on your Mac, for the exercise checks (they use pytest) and lesson 2.2.
- **Git**, to clone this repository.

## 2. Set up once

Clone the repository and go into it:

```bash
git clone https://github.com/AI-Enabled-Reality/docker-hands-on.git
```

```bash
cd docker-hands-on
```

Create a virtual environment for the exercise checks and install pytest into it:

```bash
python3 -m venv .venv
```

```bash
source .venv/bin/activate
```

```bash
pip install -r requirements.txt
```

With uv instead: `uv venv && source .venv/bin/activate && uv pip install -r requirements.txt`.

Check that Docker answers:

```bash
docker version --format '{{.Client.Version}} / {{.Server.Version}}'
```

## 3. Run a practical

Every lesson's practical is a shell session, `module-NN/NN-<lesson>.sh`. Type or paste the
commands one step at a time while you read the lesson, or run the whole session from the
repository root:

```bash
bash module-01/01-from-a-vm-to-a-container.sh
```

Each step prints a header (`=== 2. Two containers from one image`). Steps marked **Break it**
fail on purpose; the lesson explains why. Every session cleans up after itself at the end.

## 4. Check an exercise

Exercises live in `module-NN/exercises/exercise-N/`, each with a `README.md`, a `start/` folder
(your starting point) and a `solution/` folder. When you think you're done, run its check from
the repository root, with the virtual environment active:

```bash
python -m pytest module-01/exercises/exercise-1
```

Green means done. A failure says what to look at.

## 5. Stop, reset, start over

The practicals name everything they create `mNNlNN-…` (lessons) or `mNNxN-…` (exercises), and the
Compose stack from module 8 on is the project `brightlane`. To remove all of it, and nothing
else on your machine:

```bash
bash tools/reset.sh
```

## 6. Services and ports

Everything binds to `127.0.0.1`, so nothing is reachable from your network.

| Service | Host port | Used from |
|---|---|---|
| reverse proxy (nginx) | 8700 | module 6 |
| pricing API (published directly) | 8701 | module 2 |
| pricing database (PostgreSQL, when published) | 5433 | module 3 |
| lab registry (`docker compose --profile registry up -d --wait`) | 5001 | module 5 |

Port 5000 isn't used: macOS's AirPlay Receiver listens on it.

## 7. Troubleshooting

- **`failed to connect to the docker API`** (older versions: "Cannot connect to the Docker
  daemon"): Docker Desktop isn't running, or your CLI points at another context. Start Docker
  Desktop and check `docker context ls`; the active one has a `*`.
- **`port is already allocated`**: another container or program uses that host port. Find it
  with `docker ps --format '{{.Names}} {{.Ports}}'` or `lsof -nP -iTCP:<port> -sTCP:LISTEN`.
- **Pulls fail with `toomanyrequests`**: Docker Hub allows 100 pulls per 6 hours without an
  account and 200 with a free one. Run `docker login`.
- **Pulls or builds fail with certificate errors** (`x509: certificate signed by unknown
  authority`, `UnknownIssuer`): your network intercepts TLS. Lesson 10.3 shows the fix; until
  then, try another network.
- **Only lesson 5.3's own builder fails with certificate errors:** a `docker-container` builder
  runs BuildKit in its own container, which doesn't trust the certificate authority your Mac and
  Docker Desktop trust. Export that root certificate as `proxy-ca.pem` (Keychain Access, or ask
  your IT team), put it in an empty folder with this `Dockerfile`, and build it:

  ```dockerfile
  FROM moby/buildkit:v0.34.1
  COPY proxy-ca.pem /usr/local/share/ca-certificates/proxy-ca.crt
  RUN cat /usr/local/share/ca-certificates/proxy-ca.crt >> /etc/ssl/certs/ca-certificates.crt
  ```

  ```bash
  docker build -t local/buildkit-with-proxy-ca:v0.34.1 <that folder>
  export LAB_BUILDKIT_IMAGE=local/buildkit-with-proxy-ca:v0.34.1
  ```

  Lesson 5.3's session and exercise 5.2's check use `LAB_BUILDKIT_IMAGE` when it's set. Keep the
  certificate out of the repository.
- **Port 5001 is already allocated:** a lab registry from another lesson or exercise is still
  running. `docker ps --filter name=m05` shows it; `docker rm -f -v <name>` removes it, and
  `docker compose --profile registry down` stops the Compose one.
- **Out of disk space:** `docker system df` shows what uses it; module 5 shows how to clean up.
- **Docker Desktop is slow or containers are killed:** give the VM more memory in Settings →
  Resources.

## 8. Versions

Tested on 2026-10-23 on an Apple Silicon Mac (macOS 27):

| Component | Version |
|---|---|
| Docker Desktop | 4.96.3 |
| Docker Engine | 29.9.2 |
| Docker Compose | 5.6.1 |
| Docker Buildx / BuildKit | 0.38.1 / 0.34.0 (in Docker Desktop), 0.34.1 (`moby/buildkit`, lesson 5.3) |
| containerd / runc | 2.4.2 / 1.5.2 |
| Python (in the images) | 3.14.9 (`python:3.14.9-slim-trixie`) |
| The app's packages | FastAPI 0.161.1, Uvicorn 0.54.0, psycopg 3.3.6, pydantic-settings 2.16.1, DuckDB 2.0.0 (all in `app/uv.lock`) |
| PostgreSQL | 18.6 (`postgres:18.6-trixie`) |
| Alpine (small helper image) | 3.24.3 |
| Registry | 3.1.2 |
| pytest (host-side checks) | 9.1.1 |

## 9. Layout

| Path | What it holds |
|---|---|
| `app/` | Brightlane's pricing service: the code you containerize (`src/pricing/`), its tests, `pyproject.toml` and `uv.lock`, and the database's schema and seed (`db/init/`) |
| `module-NN/` | the practicals (`NN-<lesson>.sh`), each lesson's files, and `exercises/` |
| `common/` | small Python helpers the exercise checks use |
| `tools/` | `reset.sh` and helpers some lessons start |
| `compose.yaml` | lab support services (the registry); the pricing stack is built in the modules |
| `conftest.py`, `requirements.txt` | pytest setup for the checks |

Licence: MIT (code). The course text is CC BY-NC 4.0.
