"""Create deterministic sandbox matching output from standardized Parquet data."""

from pathlib import Path

import pandas as pd


INPUT_DIR = Path("/opt/ml/processing/input/data")
OUTPUT_DIR = Path("/opt/ml/processing/output")


parquet_files = sorted(INPUT_DIR.rglob("*.parquet"))
if not parquet_files:
    raise RuntimeError(f"No standardized Parquet files found under {INPUT_DIR}")

standardized = pd.concat(
    [pd.read_parquet(path) for path in parquet_files], ignore_index=True
)
if standardized.empty:
    raise RuntimeError("The standardized input is empty")

required_columns = {"customer_id", "first_name", "last_name"}
missing_columns = required_columns.difference(standardized.columns)
if missing_columns:
    raise RuntimeError(f"Missing required columns: {sorted(missing_columns)}")

matching = pd.DataFrame(
    {
        "source_record_id": standardized["customer_id"].astype(str),
        "matched_record_id": standardized["customer_id"].astype(str),
        "match_status": "UNIQUE",
        "match_score": 1.0,
        "display_name": (
            standardized["first_name"].fillna("").str.strip()
            + " "
            + standardized["last_name"].fillna("").str.strip()
        ).str.strip(),
    }
)

table_output_dir = OUTPUT_DIR / "merged_clean"
table_output_dir.mkdir(parents=True, exist_ok=True)
matching.to_parquet(table_output_dir / "part-00000.parquet", index=False)
print(f"Wrote {len(matching)} merged-clean row(s) to {table_output_dir}")
