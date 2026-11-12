import duckdb
from pathlib import Path

# Define database path
BASE_DIR = Path(__file__).resolve().parent.parent
DB_PATH = BASE_DIR / "data" / "boost_churn.duckdb"

# Create database connection
con = duckdb.connect(str(DB_PATH))

# Create schemas
schemas = ["raw", "staging", "mart"]

for schema in schemas:
    con.execute(f"CREATE SCHEMA IF NOT EXISTS {schema}")

print("Database initialized successfully!")

# Display schemas
result = con.execute("""
    SELECT schema_name
    FROM information_schema.schemata
    ORDER BY schema_name
""").fetchall()

for row in result:
    print(row[0])

con.close()