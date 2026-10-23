-- Brightlane's pricing database. The postgres image runs every *.sql file in
-- /docker-entrypoint-initdb.d once, when it creates an empty database.

CREATE TABLE sites (
    site_id     text PRIMARY KEY,
    site_name   text NOT NULL,
    region      text NOT NULL CHECK (region IN ('N', 'C', 'V', 'M')),
    town        text NOT NULL,
    chargers    integer NOT NULL CHECK (chargers > 0),
    opened_on   date NOT NULL
);

CREATE TABLE tariffs (
    tariff_id        text PRIMARY KEY,
    site_id          text NOT NULL REFERENCES sites,
    price_per_kwh    numeric(6, 2) NOT NULL CHECK (price_per_kwh > 0),
    idle_fee_per_min numeric(6, 2) NOT NULL CHECK (idle_fee_per_min >= 0),
    valid_from       date NOT NULL,
    UNIQUE (site_id, valid_from)
);

-- One row per charging session, priced at the tariff valid on the day it started.
CREATE TABLE session_charges (
    session_id   text PRIMARY KEY,
    site_id      text NOT NULL REFERENCES sites,
    charger_id   text NOT NULL,
    started_at   timestamptz NOT NULL,
    ended_at     timestamptz NOT NULL,
    energy_kwh   numeric(8, 3) NOT NULL,
    idle_minutes integer NOT NULL DEFAULT 0,
    tariff_id    text NOT NULL REFERENCES tariffs,
    amount_eur   numeric(10, 2) NOT NULL
);
CREATE INDEX session_charges_site_started ON session_charges (site_id, started_at);

-- Every quote the API gives, for audit.
CREATE TABLE quotes (
    id           bigserial PRIMARY KEY,
    site_id      text NOT NULL,
    energy_kwh   numeric(8, 3) NOT NULL,
    idle_minutes integer NOT NULL,
    tariff_id    text NOT NULL,
    amount_eur   numeric(10, 2) NOT NULL,
    quoted_at    timestamptz NOT NULL DEFAULT now()
);

-- The worker's queue: the API inserts, a worker claims with FOR UPDATE SKIP LOCKED.
CREATE TABLE statement_jobs (
    id          bigserial PRIMARY KEY,
    site_id     text NOT NULL,
    period      text NOT NULL,
    status      text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'running', 'done', 'failed')),
    created_at  timestamptz NOT NULL DEFAULT now(),
    started_at  timestamptz,
    finished_at timestamptz,
    worker      text,
    rows        integer,
    file        text,
    error       text
);
