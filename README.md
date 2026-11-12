# Plume Staking: dbt Modeling Project

Models a daily Plume staking dataset (CSV) in Postgres with dbt, in three layers:
staging, intermediate and marts.

## Dataset
`extract/data/plume_staking.csv` is a daily snapshot of Plume staking: 522 rows,
one per day, from 2025-06-05 to 2026-11-08. Columns: total PLUME staked, its USD
value, number of stakers, and provider-reported 24h/7d/30d growth percentages.
The CSV is committed to the repo, so the pipeline does not depend on any API.

## Architecture

    CSV -> extract script -> Postgres (public.raw_plume_staking)
        -> stg_plume_staking          (view: cast + rename only)
        -> int_plume_staking_daily    (view: logic and decisions)
        -> fct_plume_staking_daily    (table: business table, one row per day)

| Layer | Model | What it does |
|---|---|---|
| staging | `stg_plume_staking` | Casts raw text columns to proper types and renames them. `source()` is used only here. |
| intermediate | `int_plume_staking_daily` | Recomputes day-over-day changes with `lag()` (the provider growth columns are zero-filled at the start of the series), derives implied PLUME price and average stake per staker, and classifies each day (`net_flow_direction`, `staker_trend`, `move_size`). The first day is labelled `baseline`. |
| marts | `fct_plume_staking_daily` | Final table read by downstream tools. Grain: one row per calendar day. |

Thresholds are dbt vars in `dbt_project.yml`: `flow_threshold_pct` (default 0.5)
and `large_move_pct` (default 5).

## Prerequisites
- Git
- Docker with Compose v2
- [uv](https://docs.astral.sh/uv/) (installs Python and the dependencies)
- A free host port for Postgres (set as `DB_PORT` in `.env`)

## Run from scratch

    git clone <your-repo> && cd <your-repo>
    cp .env.example .env              # fill DB_*, never commit .env
    set -a && source .env && set +a   # dbt reads DB_* from the shell environment
    docker compose up -d              # Postgres (wait until `docker compose ps` shows healthy)
    uv sync                           # dependencies
    uv run python extract/load_plume_staking.py   # raw data -> Postgres
    uv run dbt build                  # models + tests, all green

Expected result: the extractor prints `Loaded 522 CSV rows; table now has 522 rows.`
and `dbt build` ends with `PASS=50 WARN=0 ERROR=0`.

Notes:
- dbt does not read `.env` files itself, hence the `source .env` line. Alternative
  without it: `uv run --env-file .env dbt build`.
- `.env.example` sets `DBT_PROFILES_DIR=.` so dbt uses this repo's `profiles.yml`.
- If the host port is already taken, change `DB_PORT` in `.env` before `docker compose up`.
- The Postgres user, password and database are created from `.env` the first time the
  container starts. If you change them later, reset first (below).

## Environment variables (`.env.example`)

| Variable | Meaning |
|---|---|
| `DB_HOST` | Postgres host (`localhost`) |
| `DB_PORT` | Host port mapped to Postgres |
| `DB_USER` / `DB_PASS` | Postgres user and password (created by Docker) |
| `DB_NAME` | Database name (created by Docker) |
| `DBT_PROFILES_DIR` | Makes dbt use this repo's `profiles.yml` |

## Idempotency
`extract/load_plume_staking.py` upserts on `date` (primary key), so re-running it never
duplicates rows. See `extract/README.md`.

## Reset

    docker compose down -v            # removes the container and its data volume

## Repo layout

    docker-compose.yml  .env.example  pyproject.toml  uv.lock
    dbt_project.yml     profiles.yml
    extract/            load_plume_staking.py, data/plume_staking.csv, README.md
    models/             staging/  intermediate/  marts/   (each with schema.yml)
