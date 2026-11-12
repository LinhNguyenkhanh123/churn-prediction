
import duckdb
from pathlib import Path

# 1. Define paths
BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data" / "raw"
DB_PATH = BASE_DIR / "data" / "boost_churn.duckdb"

# 2. Connect to DuckDB
con = duckdb.connect(str(DB_PATH))

# 3. Get CSV files
csv_files = sorted(DATA_DIR.glob("*.csv"))

if not csv_files:
    raise FileNotFoundError("No CSV files found in data/raw")

print(f"Found {len(csv_files)} CSV files.")

# 4. Load CSV files into RAW schema
try:
    for file in csv_files:

        table_name = file.stem

        # Check whether table already exists
        exists = con.execute("""
            SELECT COUNT(*)
            FROM information_schema.tables
            WHERE table_schema = 'raw'
              AND table_name = ?
        """, [table_name]).fetchone()[0]

        if exists:
            print(f"SKIPPED: raw.{table_name} already exists.")
            continue

        # Create table using all VARCHAR columns
        con.execute(
            f"""
            CREATE TABLE raw."{table_name}" AS
            SELECT *
            FROM read_csv(
                ?,
                header = true,
                all_varchar = true
            )
            """,
            [str(file)]
        )

        # Count rows in source CSV
        source_count = con.execute(
            """
            SELECT COUNT(*)
            FROM read_csv(
                ?,
                header = true,
                all_varchar = true
            )
            """,
            [str(file)]
        ).fetchone()[0]

        # Count rows in DuckDB
        loaded_count = con.execute(
            f'SELECT COUNT(*) FROM raw."{table_name}"'
        ).fetchone()[0]

        status = "SUCCESS" if source_count == loaded_count else "FAILED"

        print(
            f"{status}: {table_name} | "
            f"Source: {source_count:,} | "
            f"Loaded: {loaded_count:,}"
        )

finally:
    con.close()

print("\nRAW ingestion completed.")
