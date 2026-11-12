"""Load extract/data/plume_staking.csv into Postgres table public.raw_plume_staking.

Idempotent: `date` is the primary key and rows are upserted, so re-running
the same file never duplicates rows. All columns are stored as TEXT
(raw layer); casting happens once, in dbt staging.
"""
import csv
import os
from pathlib import Path

import psycopg2
from dotenv import load_dotenv
from psycopg2.extras import execute_values

CSV_PATH = Path(__file__).parent / "data" / "plume_staking.csv"
TABLE = "public.raw_plume_staking"
EXPECTED = [
    "date", "amount_staked", "amount_staked_usd",
    "amount_staked_growth_24h", "amount_staked_growth_7D", "amount_staked_growth_30D",
    "stakers", "stakers_growth_24h", "stakers_growth_7D", "stakers_growth_30D",
]


def main() -> None:
    load_dotenv()
    with open(CSV_PATH, newline="", encoding="utf-8-sig") as f:
        reader = csv.reader(f)
        header = next(reader)
        if header != EXPECTED:
            raise SystemExit(f"Unexpected CSV header: {header}")
        rows = [r for r in reader if r]

    cols = ", ".join(f'"{c}"' for c in EXPECTED)
    updates = ", ".join(f'"{c}" = EXCLUDED."{c}"' for c in EXPECTED[1:])
    ddl = f"""
        CREATE TABLE IF NOT EXISTS {TABLE} (
            "date" TEXT PRIMARY KEY,
            {", ".join(f'"{c}" TEXT' for c in EXPECTED[1:])}
        )
    """

    conn = psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASS"],
        dbname=os.environ["DB_NAME"],
    )
    with conn, conn.cursor() as cur:
        cur.execute(ddl)
        execute_values(
            cur,
            f'INSERT INTO {TABLE} ({cols}) VALUES %s '
            f'ON CONFLICT ("date") DO UPDATE SET {updates}',
            rows,
        )
        cur.execute(f"SELECT count(*) FROM {TABLE}")
        print(f"Loaded {len(rows)} CSV rows; table now has {cur.fetchone()[0]} rows.")
    conn.close()


if __name__ == "__main__":
    main()