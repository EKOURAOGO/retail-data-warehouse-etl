#!/usr/bin/env python3
"""
ETL Pipeline Orchestrator — Retail Data Warehouse
===================================================
Simulates what a workflow orchestrator (Airflow, dbt, Dagster)
would do: run each layer of the pipeline in order, fail fast on
the first error, and log timing and row counts for every step.

Usage:
    python3 run_pipeline.py
"""

import subprocess
import sys
import time
from datetime import datetime

MYSQL_USER = "root"

PIPELINE_STEPS = [
    {
        "name": "00_source_schema",
        "description": "Create source OLTP database (retail_analytics)",
        "file": "00_source_schema.sql",
        "database": None,
    },
    {
        "name": "00_source_seed_data",
        "description": "Load source OLTP seed data",
        "file": "00_source_seed_data.sql",
        "database": None,
    },
    {
        "name": "01_staging_schema",
        "description": "Create staging layer (retail_dw)",
        "file": "01_staging_schema.sql",
        "database": None,
    },
    {
        "name": "02_extract",
        "description": "EXTRACT — source -> staging",
        "file": "02_etl_extract_to_staging.sql",
        "database": "retail_dw",
    },
    {
        "name": "03_star_schema_ddl",
        "description": "Create star schema (dimensions + fact table)",
        "file": "03_star_schema_ddl.sql",
        "database": "retail_dw",
    },
    {
        "name": "04_transform_load",
        "description": "TRANSFORM & LOAD — staging -> star schema",
        "file": "04_etl_transform_load.sql",
        "database": "retail_dw",
    },
    {
        "name": "05_scd2_demo",
        "description": "Incremental load demo — SCD2 city change",
        "file": "05_etl_scd2_demo.sql",
        "database": "retail_dw",
    },
    {
        "name": "06_marts",
        "description": "Build analytical marts (views)",
        "file": "06_marts_views.sql",
        "database": "retail_dw",
    },
]


def run_sql_file(filepath, database=None):
    cmd = ["mysql", "-u", MYSQL_USER]
    if database:
        cmd.append(database)
    with open(filepath, "rb") as f:
        result = subprocess.run(cmd, stdin=f, capture_output=True, text=True)
    return result.returncode, result.stdout, result.stderr


def get_row_counts():
    query = """
    SELECT 'staging' AS layer, 'stg_sales_order_items' AS tbl, COUNT(*) AS n FROM retail_dw.stg_sales_order_items
    UNION ALL SELECT 'star', 'fact_sales', COUNT(*) FROM retail_dw.fact_sales
    UNION ALL SELECT 'star', 'dim_customer', COUNT(*) FROM retail_dw.dim_customer
    UNION ALL SELECT 'star', 'dim_date', COUNT(*) FROM retail_dw.dim_date;
    """
    result = subprocess.run(
        ["mysql", "-u", MYSQL_USER, "-N", "-B", "-e", query],
        capture_output=True, text=True
    )
    return result.stdout.strip()


def main():
    print("=" * 70)
    print(f"RETAIL DATA WAREHOUSE — ETL PIPELINE RUN")
    print(f"Started at: {datetime.now().isoformat()}")
    print("=" * 70)

    pipeline_start = time.time()

    for step in PIPELINE_STEPS:
        step_start = time.time()
        print(f"\n[{step['name']}] {step['description']}")
        print(f"  -> running {step['file']}...")

        returncode, stdout, stderr = run_sql_file(step["file"], step["database"])
        elapsed = time.time() - step_start

        if returncode != 0:
            print(f"  FAILED after {elapsed:.2f}s")
            print(f"  --- stderr ---\n{stderr}")
            print("\n" + "=" * 70)
            print(f"PIPELINE FAILED at step: {step['name']}")
            print("=" * 70)
            sys.exit(1)

        print(f"  OK ({elapsed:.2f}s)")

    total_elapsed = time.time() - pipeline_start

    print("\n" + "=" * 70)
    print("ROW COUNTS AFTER PIPELINE RUN")
    print("=" * 70)
    print(get_row_counts())

    print("\n" + "=" * 70)
    print(f"PIPELINE COMPLETED SUCCESSFULLY in {total_elapsed:.2f}s")
    print(f"Finished at: {datetime.now().isoformat()}")
    print("=" * 70)


if __name__ == "__main__":
    main()
