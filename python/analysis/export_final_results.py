"""
PulsePay Product Analytics
Final Results Export

Exports the final analytical outputs from MySQL into CSV files
for dashboard validation, GitHub documentation, and case-study writing.
"""

from getpass import getpass
from pathlib import Path

import mysql.connector
import pandas as pd


# ============================================================
# PROJECT PATHS
# ============================================================

PROJECT_ROOT = Path(__file__).resolve().parents[2]

OUTPUT_DIR = PROJECT_ROOT / "data" / "processed" / "final_results"

OUTPUT_DIR.mkdir(
    parents=True,
    exist_ok=True
)


# ============================================================
# DATABASE CONFIGURATION
# ============================================================

DB_CONFIG = {
    "host": "localhost",
    "port": 3306,
    "user": "root",
    "database": "pulsepay_analytics",
}


# ============================================================
# FINAL ANALYTICAL OUTPUTS
# ============================================================

QUERIES = {

    "executive_kpis": """
        SELECT *
        FROM vw_executive_kpis;
    """,

    "weekly_north_star": """
        SELECT *
        FROM vw_weekly_north_star
        ORDER BY week_start;
    """,

    "onboarding_funnel": """
        SELECT *
        FROM vw_onboarding_funnel
        ORDER BY step_order;
    """,

    "kyc_device_version": """
        SELECT *
        FROM vw_kyc_device_version
        ORDER BY device_type, app_version;
    """,

    "weekly_kyc_trend": """
        SELECT *
        FROM vw_weekly_kyc_trend
        ORDER BY week_start, device_type, app_version;
    """,

    "acquisition_quality": """
        SELECT *
        FROM vw_acquisition_quality
        ORDER BY acquisition_quality_score DESC;
    """,

    "activation_retention": """
        SELECT *
        FROM vw_activation_retention
        ORDER BY group_order;
    """,

    "cohort_retention": """
        SELECT *
        FROM vw_cohort_retention
        ORDER BY cohort_month;
    """,

    "experiment_scorecard": """
        SELECT *
        FROM vw_experiment_scorecard
        ORDER BY variant;
    """,

    "kyc_incident_impact": """
        SELECT *
        FROM vw_kyc_incident_impact;
    """,
}


# ============================================================
# DATABASE CONNECTION
# ============================================================

def connect_to_mysql():

    print("=" * 70)
    print("PULSEPAY PRODUCT ANALYTICS")
    print("FINAL RESULTS EXPORT")
    print("=" * 70)

    password = getpass(
        "\nEnter your MySQL root password: "
    )

    connection = mysql.connector.connect(

        host=DB_CONFIG["host"],

        port=DB_CONFIG["port"],

        user=DB_CONFIG["user"],

        password=password,

        database=DB_CONFIG["database"],

    )

    print(
        "\nConnected successfully to MySQL."
    )

    return connection


# ============================================================
# EXPORT RESULTS
# ============================================================

def export_results(connection):

    print(
        f"\nExport directory:\n{OUTPUT_DIR}\n"
    )

    for result_name, query in QUERIES.items():

        print(
            f"Exporting: {result_name}"
        )

        cursor = connection.cursor(
            dictionary=True
        )

        cursor.execute(query)

        rows = cursor.fetchall()

        cursor.close()

        df = pd.DataFrame(rows)

        output_file = (
            OUTPUT_DIR
            /
            f"{result_name}.csv"
        )

        df.to_csv(
            output_file,
            index=False
        )

        print(
            f"  Rows: {len(df):,}"
        )

        print(
            f"  Saved: {output_file.name}"
        )


# ============================================================
# CREATE EXPORT MANIFEST
# ============================================================

def create_manifest():

    manifest_rows = []

    for csv_file in sorted(
        OUTPUT_DIR.glob("*.csv")
    ):

        df = pd.read_csv(
            csv_file
        )

        manifest_rows.append({

            "file_name":
                csv_file.name,

            "row_count":
                len(df),

            "column_count":
                len(df.columns),

            "columns":
                ", ".join(
                    df.columns
                ),

        })

    manifest_df = pd.DataFrame(
        manifest_rows
    )

    manifest_file = (
        OUTPUT_DIR
        /
        "export_manifest.csv"
    )

    manifest_df.to_csv(
        manifest_file,
        index=False
    )

    print(
        "\nExport manifest created:"
    )

    print(
        f"{manifest_file}"
    )


# ============================================================
# MAIN
# ============================================================

def main():

    connection = None

    try:

        connection = (
            connect_to_mysql()
        )

        export_results(
            connection
        )

        create_manifest()

        print(
            "\n"
            + "=" * 70
        )

        print(
            "FINAL RESULTS EXPORT COMPLETE"
        )

        print(
            "=" * 70
        )

    except Exception as error:

        print(
            f"\nERROR: {error}"
        )

        raise

    finally:

        if (
            connection is not None

            and connection.is_connected()
        ):

            connection.close()

            print(
                "\nMySQL connection closed."
            )


if __name__ == "__main__":
    main()