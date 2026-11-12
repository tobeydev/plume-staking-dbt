# extract

Loads `data/plume_staking.csv` (a committed snapshot, so no API is needed)
into Postgres table `public.raw_plume_staking`. All columns are stored as TEXT;
dbt staging does the casting.

Original code, not the lesson's Uniswap extractor.

Run from the repo root (requires `.env` and a running Postgres):

    uv run python extract/load_plume_staking.py

Idempotent: `date` is the primary key and rows are upserted, so re-running
never creates duplicates.