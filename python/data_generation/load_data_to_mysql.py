from pathlib import Path
from getpass import getpass
import sys

import pandas as pd
import mysql.connector
from mysql.connector import Error


# ============================================================
# PULSEPAY — CSV TO MYSQL DATA LOADER
# ============================================================

DB_CONFIG = {
    "host": "localhost",
    "port": 3306,
    "user": "root",
    "database": "pulsepay_analytics",
}

# Project root:
# pulsepay-product-analytics/
PROJECT_ROOT = Path(__file__).resolve().parents[2]

DATA_DIR = PROJECT_ROOT / "data" / "raw"

TABLES = [
    {
        "table": "users",
        "file": "users.csv",
        "columns": [
            "user_id",
            "signup_timestamp",
            "acquisition_channel",
            "campaign_name",
            "device_type",
            "city_tier",
            "age_group",
            "signup_app_version",
            "is_premium",
        ],
    },
    {
        "table": "kyc_applications",
        "file": "kyc_applications.csv",
        "columns": [
            "kyc_id",
            "user_id",
            "started_at",
            "completed_at",
            "status",
            "failure_reason",
            "flow_version",
        ],
    },
    {
        "table": "events",
        "file": "events.csv",
        "columns": [
            "event_id",
            "user_id",
            "session_id",
            "event_name",
            "event_timestamp",
            "feature_name",
            "app_version",
            "device_type",
            "event_properties",
        ],
    },
    {
        "table": "transactions",
        "file": "transactions.csv",
        "columns": [
            "transaction_id",
            "user_id",
            "transaction_timestamp",
            "transaction_type",
            "amount",
            "status",
            "failure_reason",
            "payment_partner",
        ],
    },
    {
        "table": "experiment_assignments",
        "file": "experiment_assignments.csv",
        "columns": [
            "assignment_id",
            "experiment_id",
            "user_id",
            "variant",
            "assigned_at",
        ],
    },
    {
        "table": "support_tickets",
        "file": "support_tickets.csv",
        "columns": [
            "ticket_id",
            "user_id",
            "created_at",
            "category",
            "issue_text",
            "sentiment",
            "resolution_time_hours",
        ],
    },
]

BATCH_SIZE = 1000


def validate_files():
    print("\n[1/5] Validating CSV files...\n")

    all_valid = True

    for config in TABLES:
        file_path = DATA_DIR / config["file"]

        if file_path.exists():
            print(f"OK  {config['file']}")
        else:
            print(f"MISSING  {config['file']}")
            all_valid = False

    if not all_valid:
        print("\nSome CSV files are missing.")
        print(f"Expected location: {DATA_DIR}")
        sys.exit(1)

    print("\nAll CSV files found.")


def connect_to_mysql(password):
    print("\n[2/5] Connecting to MySQL...\n")

    try:
        connection = mysql.connector.connect(
            host=DB_CONFIG["host"],
            port=DB_CONFIG["port"],
            user=DB_CONFIG["user"],
            password=password,
            database=DB_CONFIG["database"],
        )

        if connection.is_connected():
            print("Connected successfully to MySQL.")
            return connection

    except Error as error:
        print(f"MySQL connection failed: {error}")
        sys.exit(1)


def clear_existing_data(connection):
    print("\n[3/5] Clearing partial/old imported data...\n")

    cursor = connection.cursor()

    try:
        cursor.execute("SET FOREIGN_KEY_CHECKS = 0")

        tables_to_clear = [
            "events",
            "kyc_applications",
            "transactions",
            "experiment_assignments",
            "support_tickets",
            "users",
        ]

        for table in tables_to_clear:
            cursor.execute(f"TRUNCATE TABLE {table}")
            print(f"Cleared: {table}")

        cursor.execute("SET FOREIGN_KEY_CHECKS = 1")

        connection.commit()

        print("\nOld/partial data cleared successfully.")

    except Error as error:
        connection.rollback()
        print(f"Error while clearing tables: {error}")
        sys.exit(1)

    finally:
        cursor.close()


def clean_dataframe(df):
    # Convert pandas NaN/NaT values to Python None for MySQL NULL.
    df = df.astype(object)
    df = df.where(pd.notnull(df), None)

    return df


def load_table(connection, config):
    table = config["table"]
    file_path = DATA_DIR / config["file"]
    expected_columns = config["columns"]

    print(f"\nLoading {table}...")
    print(f"Source: {config['file']}")

    df = pd.read_csv(file_path, low_memory=False)

    missing_columns = [
        column
        for column in expected_columns
        if column not in df.columns
    ]

    if missing_columns:
        print(
            f"ERROR: Missing columns in {config['file']}: "
            f"{missing_columns}"
        )
        sys.exit(1)

    df = df[expected_columns]

    df = clean_dataframe(df)

    placeholders = ", ".join(["%s"] * len(expected_columns))

    column_names = ", ".join(
        [f"`{column}`" for column in expected_columns]
    )

    insert_query = f"""
        INSERT INTO `{table}`
        ({column_names})
        VALUES ({placeholders})
    """

    cursor = connection.cursor()

    total_rows = len(df)
    inserted_rows = 0

    try:
        for start in range(0, total_rows, BATCH_SIZE):
            end = min(start + BATCH_SIZE, total_rows)

            batch = df.iloc[start:end]

            records = [
                tuple(row)
                for row in batch.itertuples(
                    index=False,
                    name=None
                )
            ]

            cursor.executemany(
                insert_query,
                records
            )

            connection.commit()

            inserted_rows += len(records)

            print(
                f"\rInserted "
                f"{inserted_rows:,}/{total_rows:,} rows",
                end="",
                flush=True,
            )

        print(f"\nSUCCESS: {table} loaded.")

    except Error as error:
        connection.rollback()

        print(f"\nERROR while loading {table}:")
        print(error)

        sys.exit(1)

    finally:
        cursor.close()


def validate_database(connection):
    print("\n[5/5] Validating database row counts...\n")

    cursor = connection.cursor()

    for config in TABLES:
        table = config["table"]

        cursor.execute(
            f"SELECT COUNT(*) FROM `{table}`"
        )

        count = cursor.fetchone()[0]

        print(
            f"{table:<25} "
            f"{count:>10,} rows"
        )

    cursor.close()


def main():
    print("=" * 60)
    print("PULSEPAY PRODUCT ANALYTICS")
    print("CSV TO MYSQL DATA LOADER")
    print("=" * 60)

    validate_files()

    password = getpass(
        "\nEnter your MySQL root password: "
    )

    connection = connect_to_mysql(password)

    try:
        clear_existing_data(connection)

        print("\n[4/5] Loading PulsePay dataset...")

        for config in TABLES:
            load_table(
                connection,
                config
            )

        validate_database(connection)

        print("\n" + "=" * 60)
        print("PULSEPAY DATASET LOADED SUCCESSFULLY")
        print("=" * 60)

    finally:
        if connection.is_connected():
            connection.close()

            print(
                "\nMySQL connection closed."
            )


if __name__ == "__main__":
    main()