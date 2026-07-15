"""
PulsePay Product Analytics
Experiment Analysis: KYC Flow A/B Test

Purpose:
- Pull experiment outcomes from MySQL
- Compare control vs treatment KYC completion
- Calculate absolute and relative lift
- Run a two-proportion z-test
- Calculate a 95% confidence interval
- Check sample ratio mismatch
- Produce an evidence-based experiment recommendation
"""

from getpass import getpass
from math import erf, sqrt

import mysql.connector
import pandas as pd


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
# STATISTICAL SETTINGS
# ============================================================

ALPHA = 0.05
Z_CRITICAL_95 = 1.959963984540054


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def normal_cdf(x):
    """
    Standard normal cumulative distribution function.
    """
    return 0.5 * (1 + erf(x / sqrt(2)))


def two_sided_p_value(z_score):
    """
    Two-sided p-value from a standard normal z-score.
    """
    return 2 * (1 - normal_cdf(abs(z_score)))


def connect_to_mysql():
    """
    Securely connect to MySQL.
    Password is requested in the terminal and is not stored.
    """

    print("=" * 70)
    print("PULSEPAY PRODUCT ANALYTICS")
    print("KYC FLOW A/B TEST — STATISTICAL ANALYSIS")
    print("=" * 70)

    password = getpass("\nEnter your MySQL root password: ")

    connection = mysql.connector.connect(
        host=DB_CONFIG["host"],
        port=DB_CONFIG["port"],
        user=DB_CONFIG["user"],
        password=password,
        database=DB_CONFIG["database"],
    )

    print("\nConnected successfully to MySQL.")

    return connection


# ============================================================
# LOAD EXPERIMENT DATA
# ============================================================

def load_experiment_data(connection):
    """
    Create one row per experiment user.

    completed_kyc:
        1 if the user completed KYC
        0 otherwise

    contacted_support:
        1 if the user contacted support
        0 otherwise

    activated:
        1 if the user completed a first successful transaction
        0 otherwise
    """

    query = """
    SELECT
        ea.user_id,
        ea.variant,

        MAX(
            CASE
                WHEN k.status = 'completed'
                THEN 1
                ELSE 0
            END
        ) AS completed_kyc,

        MAX(
            CASE
                WHEN s.ticket_id IS NOT NULL
                THEN 1
                ELSE 0
            END
        ) AS contacted_support,

        MAX(
            CASE
                WHEN e.event_name =
                     'first_successful_transaction'
                THEN 1
                ELSE 0
            END
        ) AS activated

    FROM experiment_assignments ea

    LEFT JOIN kyc_applications k
        ON ea.user_id = k.user_id

    LEFT JOIN support_tickets s
        ON ea.user_id = s.user_id

    LEFT JOIN events e
        ON ea.user_id = e.user_id

    WHERE
        ea.experiment_id = 1

    GROUP BY
        ea.user_id,
        ea.variant
    """

    cursor = connection.cursor(dictionary=True)

    cursor.execute(query)

    rows = cursor.fetchall()

    cursor.close()

    df = pd.DataFrame(rows)

    if df.empty:
        raise ValueError(
            "No experiment data was found in experiment_assignments."
        )

    return df


# ============================================================
# DATA QUALITY CHECKS
# ============================================================

def validate_experiment_data(df):
    """
    Validate experiment structure before testing outcomes.
    """

    print("\n" + "=" * 70)
    print("1. EXPERIMENT DATA VALIDATION")
    print("=" * 70)

    expected_variants = {"control", "treatment"}

    actual_variants = set(
        df["variant"]
        .dropna()
        .astype(str)
        .str.lower()
        .unique()
    )

    print(f"\nTotal experiment users: {len(df):,}")
    print(f"Variants found: {sorted(actual_variants)}")

    if actual_variants != expected_variants:
        raise ValueError(
            "Expected exactly two variants: control and treatment."
        )

    duplicate_users = df["user_id"].duplicated().sum()

    print(f"Duplicate experiment users: {duplicate_users:,}")

    if duplicate_users > 0:
        raise ValueError(
            "Duplicate users found in the experiment dataset."
        )

    print("\nExperiment structure validation: PASSED")


# ============================================================
# EXPERIMENT SCORECARD
# ============================================================

def create_scorecard(df):
    """
    Build descriptive metrics for each experiment variant.
    """

    scorecard = (
        df.groupby("variant")
        .agg(
            assigned_users=("user_id", "nunique"),
            completed_kyc_users=("completed_kyc", "sum"),
            kyc_completion_rate=("completed_kyc", "mean"),
            support_contact_rate=("contacted_support", "mean"),
            activation_rate=("activated", "mean"),
        )
        .reset_index()
    )

    return scorecard


def print_scorecard(scorecard):
    """
    Print a readable experiment scorecard.
    """

    display_df = scorecard.copy()

    display_df["kyc_completion_rate"] = (
        display_df["kyc_completion_rate"] * 100
    ).round(2)

    display_df["support_contact_rate"] = (
        display_df["support_contact_rate"] * 100
    ).round(2)

    display_df["activation_rate"] = (
        display_df["activation_rate"] * 100
    ).round(2)

    display_df = display_df.rename(
        columns={
            "kyc_completion_rate": "kyc_completion_rate_pct",
            "support_contact_rate": "support_contact_rate_pct",
            "activation_rate": "activation_rate_pct",
        }
    )

    print("\n" + "=" * 70)
    print("2. EXPERIMENT SCORECARD")
    print("=" * 70)

    print(
        "\n"
        + display_df.to_string(
            index=False
        )
    )


# ============================================================
# SAMPLE RATIO MISMATCH CHECK
# ============================================================

def sample_ratio_mismatch_test(scorecard):
    """
    Chi-square goodness-of-fit test for a 50/50 experiment split.

    With two categories and one degree of freedom:
        chi-square = z^2

    The two-sided normal tail is equivalent to the
    chi-square(1) upper-tail probability.
    """

    counts = dict(
        zip(
            scorecard["variant"],
            scorecard["assigned_users"],
        )
    )

    control_n = counts["control"]
    treatment_n = counts["treatment"]

    total_n = control_n + treatment_n

    expected_n = total_n / 2

    chi_square = (
        ((control_n - expected_n) ** 2 / expected_n)
        +
        ((treatment_n - expected_n) ** 2 / expected_n)
    )

    p_value = 2 * (
        1 - normal_cdf(
            sqrt(chi_square)
        )
    )

    print("\n" + "=" * 70)
    print("3. SAMPLE RATIO MISMATCH CHECK")
    print("=" * 70)

    print(f"\nControl users:   {control_n:,}")
    print(f"Treatment users: {treatment_n:,}")
    print("Expected split:  50% / 50%")
    print(f"Chi-square:      {chi_square:.4f}")
    print(f"P-value:         {p_value:.6f}")

    if p_value < ALPHA:
        print(
            "\nResult: WARNING — statistically significant "
            "sample ratio mismatch detected."
        )
    else:
        print(
            "\nResult: PASSED — no statistically significant "
            "sample ratio mismatch detected."
        )

    return p_value


# ============================================================
# TWO-PROPORTION Z-TEST
# ============================================================

def analyze_primary_metric(scorecard):
    """
    Compare treatment and control KYC completion rates.
    """

    metrics = scorecard.set_index("variant")

    control_n = int(
        metrics.loc[
            "control",
            "assigned_users",
        ]
    )

    treatment_n = int(
        metrics.loc[
            "treatment",
            "assigned_users",
        ]
    )

    control_successes = int(
        metrics.loc[
            "control",
            "completed_kyc_users",
        ]
    )

    treatment_successes = int(
        metrics.loc[
            "treatment",
            "completed_kyc_users",
        ]
    )

    control_rate = (
        control_successes / control_n
    )

    treatment_rate = (
        treatment_successes / treatment_n
    )

    absolute_lift = (
        treatment_rate - control_rate
    )

    if control_rate != 0:
        relative_lift = (
            absolute_lift / control_rate
        )
    else:
        relative_lift = float("nan")

    pooled_rate = (
        control_successes
        + treatment_successes
    ) / (
        control_n
        + treatment_n
    )

    pooled_standard_error = sqrt(
        pooled_rate
        *
        (1 - pooled_rate)
        *
        (
            (1 / control_n)
            +
            (1 / treatment_n)
        )
    )

    if pooled_standard_error == 0:
        z_score = 0
        p_value = 1
    else:
        z_score = (
            absolute_lift
            /
            pooled_standard_error
        )

        p_value = two_sided_p_value(
            z_score
        )

    # Unpooled standard error for confidence interval
    ci_standard_error = sqrt(

        (
            control_rate
            *
            (1 - control_rate)
            /
            control_n
        )

        +

        (
            treatment_rate
            *
            (1 - treatment_rate)
            /
            treatment_n
        )
    )

    ci_lower = (
        absolute_lift
        -
        Z_CRITICAL_95
        *
        ci_standard_error
    )

    ci_upper = (
        absolute_lift
        +
        Z_CRITICAL_95
        *
        ci_standard_error
    )

    print("\n" + "=" * 70)
    print("4. PRIMARY METRIC ANALYSIS")
    print("=" * 70)

    print(
        f"\nControl completion rate:   "
        f"{control_rate * 100:.2f}%"
    )

    print(
        f"Treatment completion rate: "
        f"{treatment_rate * 100:.2f}%"
    )

    print(
        f"\nAbsolute lift: "
        f"{absolute_lift * 100:.2f} percentage points"
    )

    print(
        f"Relative lift: "
        f"{relative_lift * 100:.2f}%"
    )

    print(
        f"\nZ-score: {z_score:.4f}"
    )

    print(
        f"P-value: {p_value:.6f}"
    )

    print(
        "\n95% confidence interval for "
        "treatment - control:"
    )

    print(
        f"[{ci_lower * 100:.2f}, "
        f"{ci_upper * 100:.2f}] percentage points"
    )

    significant = (
        p_value < ALPHA
    )

    return {
        "control_rate": control_rate,
        "treatment_rate": treatment_rate,
        "absolute_lift": absolute_lift,
        "relative_lift": relative_lift,
        "z_score": z_score,
        "p_value": p_value,
        "ci_lower": ci_lower,
        "ci_upper": ci_upper,
        "significant": significant,
    }


# ============================================================
# EXPERIMENT DECISION
# ============================================================

def print_recommendation(results, scorecard):
    """
    Produce a cautious experiment recommendation.
    """

    metrics = scorecard.set_index("variant")

    control_support = metrics.loc[
        "control",
        "support_contact_rate",
    ]

    treatment_support = metrics.loc[
        "treatment",
        "support_contact_rate",
    ]

    control_activation = metrics.loc[
        "control",
        "activation_rate",
    ]

    treatment_activation = metrics.loc[
        "treatment",
        "activation_rate",
    ]

    print("\n" + "=" * 70)
    print("5. EXPERIMENT DECISION")
    print("=" * 70)

    if (
        results["significant"]
        and results["absolute_lift"] > 0
    ):

        print(
            "\nPrimary metric result:"
            "\nThe treatment produced a statistically "
            "significant improvement in KYC completion."
        )

        if treatment_support <= control_support:
            print(
                "\nGuardrail result:"
                "\nSupport contact rate did not increase."
            )
        else:
            print(
                "\nGuardrail result:"
                "\nSupport contact rate increased. "
                "Investigate before full rollout."
            )

        print(
            "\nRecommendation:"
            "\nConsider rolling out the treatment, subject "
            "to guardrail and operational review."
        )

    elif (
        results["significant"]
        and results["absolute_lift"] < 0
    ):

        print(
            "\nPrimary metric result:"
            "\nThe treatment produced a statistically "
            "significant decline in KYC completion."
        )

        print(
            "\nRecommendation:"
            "\nDo not roll out the treatment. Investigate "
            "the treatment experience and failure points."
        )

    else:

        print(
            "\nPrimary metric result:"
            "\nThe experiment did not provide sufficient "
            "statistical evidence of a difference in "
            "KYC completion."
        )

        print(
            "\nRecommendation:"
            "\nDo not claim that the treatment improved KYC "
            "completion. Keep the control experience or "
            "continue testing with a stronger hypothesis, "
            "adequate power, and a predefined MDE."
        )

    print(
        "\nDownstream directional check:"
    )

    print(
        f"Control activation rate:   "
        f"{control_activation * 100:.2f}%"
    )

    print(
        f"Treatment activation rate: "
        f"{treatment_activation * 100:.2f}%"
    )


# ============================================================
# MAIN
# ============================================================

def main():

    connection = None

    try:

        connection = connect_to_mysql()

        df = load_experiment_data(
            connection
        )

        validate_experiment_data(
            df
        )

        scorecard = create_scorecard(
            df
        )

        print_scorecard(
            scorecard
        )

        sample_ratio_mismatch_test(
            scorecard
        )

        results = analyze_primary_metric(
            scorecard
        )

        print_recommendation(
            results,
            scorecard
        )

        print("\n" + "=" * 70)
        print("ANALYSIS COMPLETE")
        print("=" * 70)

    except Exception as error:

        print(
            f"\nERROR: {error}"
        )

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