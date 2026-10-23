# syntax=docker/dockerfile:1
# Lesson 10.3: trust the company's certificate authority while installing, and only then.
#   docker build -f module-10/03-ca-trust/Dockerfile --secret id=company_ca,src=<company-ca.pem> \
#     -t brightlane/tariffs-check module-10/03-ca-trust

# ---- Stage 1, build: the CA is available to one RUN, through a secret mount, and nowhere else.
FROM python:3.14.9-slim-trixie AS build
COPY --from=ghcr.io/astral-sh/uv:0.13.5 /uv /bin/uv
ENV UV_PYTHON_DOWNLOADS=0
# SSL_CERT_FILE replaces the roots uv (and pip, and Python's urllib) trust, so the bundle is the
# image's roots plus the company's CA, in a file that exists only during this step. Without --secret
# (in CI, outside the company network) there's no file, and the step trusts the usual roots.
RUN --mount=type=secret,id=company_ca \
    if [ -f /run/secrets/company_ca ]; then \
      cat /etc/ssl/certs/ca-certificates.crt /run/secrets/company_ca > /tmp/ca-bundle.pem; \
      export SSL_CERT_FILE=/tmp/ca-bundle.pem; \
    fi \
 && uv venv /opt/venv \
 && VIRTUAL_ENV=/opt/venv uv pip install --index-url https://host.docker.internal:8443/simple/ brightlane-tariffs \
 && rm -f /tmp/ca-bundle.pem

# ---- Stage 2, runtime: the installed packages, and the image's own trust store, unchanged.
FROM python:3.14.9-slim-trixie
COPY --from=build /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
CMD ["python", "-c", "import brightlane_tariffs as t; print('rulebook', t.RULEBOOK, 'motorway', t.MOTORWAY_PRICE_PER_KWH, 'EUR/kWh from', t.MOTORWAY_FROM)"]
