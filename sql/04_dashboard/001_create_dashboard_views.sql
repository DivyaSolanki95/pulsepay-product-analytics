USE pulsepay_analytics;

-- ============================================================
-- PULSEPAY PRODUCT ANALYTICS
-- DASHBOARD DATA LAYER
-- ============================================================
--
-- Purpose:
-- Create reusable MySQL views for the PulsePay executive
-- product analytics dashboard.
--
-- Dashboard Pages:
-- 1. Executive Overview
-- 2. Funnel & Activation
-- 3. Retention & Cohorts
-- 4. Root-Cause Investigation
-- 5. Acquisition Quality
-- 6. Experiment Results
--
-- ============================================================


-- ============================================================
-- VIEW 1: EXECUTIVE KPI SUMMARY
-- ============================================================

CREATE OR REPLACE VIEW vw_executive_kpis AS

SELECT

    (SELECT COUNT(*)
     FROM users) AS total_users,

    (SELECT COUNT(*)
     FROM transactions) AS total_transactions,

    (SELECT COUNT(*)
     FROM transactions
     WHERE status = 'success') AS successful_transactions,

    ROUND(
        100.0 *
        (
            SELECT COUNT(*)
            FROM transactions
            WHERE status = 'success'
        )
        /
        NULLIF(
            (
                SELECT COUNT(*)
                FROM transactions
            ),
            0
        ),
        2
    ) AS transaction_success_rate_pct,

    (
        SELECT COUNT(DISTINCT user_id)
        FROM transactions
        WHERE status = 'success'
    ) AS successful_transacting_users,

    ROUND(
        100.0 *
        (
            SELECT COUNT(DISTINCT user_id)
            FROM transactions
            WHERE status = 'success'
        )
        /
        NULLIF(
            (
                SELECT COUNT(*)
                FROM users
            ),
            0
        ),
        2
    ) AS successful_transactor_rate_pct,

    ROUND(
        (
            SELECT SUM(amount)
            FROM transactions
            WHERE status = 'success'
        ),
        2
    ) AS total_successful_transaction_value;


-- ============================================================
-- VIEW 2: WEEKLY NORTH STAR METRIC
-- Weekly Successful Transacting Users
-- ============================================================

CREATE OR REPLACE VIEW vw_weekly_north_star AS

SELECT

    DATE(
        transaction_timestamp
        - INTERVAL WEEKDAY(transaction_timestamp) DAY
    ) AS week_start,

    COUNT(
        DISTINCT user_id
    ) AS weekly_successful_transacting_users,

    COUNT(*) AS successful_transactions,

    ROUND(
        SUM(amount),
        2
    ) AS successful_transaction_value

FROM transactions

WHERE
    status = 'success'

GROUP BY
    DATE(
        transaction_timestamp
        - INTERVAL WEEKDAY(transaction_timestamp) DAY
    );


-- ============================================================
-- VIEW 3: ONBOARDING FUNNEL
-- ============================================================

CREATE OR REPLACE VIEW vw_onboarding_funnel AS

WITH funnel_counts AS (

    SELECT

        COUNT(
            DISTINCT user_id
        ) AS account_created,

        COUNT(
            DISTINCT CASE
                WHEN event_name = 'otp_verified'
                THEN user_id
            END
        ) AS otp_verified,

        COUNT(
            DISTINCT CASE
                WHEN event_name = 'kyc_started'
                THEN user_id
            END
        ) AS kyc_started,

        COUNT(
            DISTINCT CASE
                WHEN event_name = 'kyc_completed'
                THEN user_id
            END
        ) AS kyc_completed,

        COUNT(
            DISTINCT CASE
                WHEN event_name = 'bank_linked'
                THEN user_id
            END
        ) AS bank_linked,

        COUNT(
            DISTINCT CASE
                WHEN event_name =
                     'first_successful_transaction'
                THEN user_id
            END
        ) AS first_successful_transaction

    FROM events
)

SELECT
    1 AS step_order,
    'Account Created' AS funnel_step,
    account_created AS users
FROM funnel_counts

UNION ALL

SELECT
    2,
    'OTP Verified',
    otp_verified
FROM funnel_counts

UNION ALL

SELECT
    3,
    'KYC Started',
    kyc_started
FROM funnel_counts

UNION ALL

SELECT
    4,
    'KYC Completed',
    kyc_completed
FROM funnel_counts

UNION ALL

SELECT
    5,
    'Bank Linked',
    bank_linked
FROM funnel_counts

UNION ALL

SELECT
    6,
    'First Successful Transaction',
    first_successful_transaction
FROM funnel_counts;


-- ============================================================
-- VIEW 4: KYC PERFORMANCE BY DEVICE AND VERSION
-- ============================================================

CREATE OR REPLACE VIEW vw_kyc_device_version AS

SELECT

    u.device_type,

    u.signup_app_version AS app_version,

    COUNT(*) AS kyc_attempts,

    SUM(
        k.status = 'completed'
    ) AS completed,

    SUM(
        k.status = 'failed'
    ) AS failed,

    SUM(
        k.status = 'abandoned'
    ) AS abandoned,

    SUM(
        k.failure_reason =
        'document_upload_error'
    ) AS document_upload_errors,

    ROUND(
        100.0 *
        SUM(
            k.status = 'completed'
        )
        /
        COUNT(*),
        2
    ) AS completion_rate_pct,

    ROUND(
        100.0 *
        SUM(
            k.failure_reason =
            'document_upload_error'
        )
        /
        COUNT(*),
        2
    ) AS document_upload_error_rate_pct

FROM kyc_applications k

JOIN users u
    ON k.user_id = u.user_id

GROUP BY
    u.device_type,
    u.signup_app_version;


-- ============================================================
-- VIEW 5: WEEKLY KYC TREND
-- ============================================================

CREATE OR REPLACE VIEW vw_weekly_kyc_trend AS

SELECT

    DATE(
        k.started_at
        - INTERVAL WEEKDAY(k.started_at) DAY
    ) AS week_start,

    u.device_type,

    u.signup_app_version AS app_version,

    COUNT(*) AS kyc_started,

    SUM(
        k.status = 'completed'
    ) AS kyc_completed,

    SUM(
        k.status = 'failed'
    ) AS kyc_failed,

    ROUND(
        100.0 *
        SUM(
            k.status = 'completed'
        )
        /
        COUNT(*),
        2
    ) AS kyc_completion_rate_pct

FROM kyc_applications k

JOIN users u
    ON k.user_id = u.user_id

GROUP BY

    DATE(
        k.started_at
        - INTERVAL WEEKDAY(k.started_at) DAY
    ),

    u.device_type,

    u.signup_app_version;


-- ============================================================
-- VIEW 6: ACQUISITION QUALITY SCORECARD
-- ============================================================

CREATE OR REPLACE VIEW vw_acquisition_quality AS

WITH user_metrics AS (

    SELECT

        u.user_id,

        u.acquisition_channel,

        MAX(
            k.status = 'completed'
        ) AS completed_kyc,

        MAX(
            CASE
                WHEN e.event_name =
                     'first_successful_transaction'
                THEN 1
                ELSE 0
            END
        ) AS activated,

        MAX(
            CASE

                WHEN
                    t.status = 'success'

                    AND DATEDIFF(
                        DATE(
                            t.transaction_timestamp
                        ),
                        DATE(
                            u.signup_timestamp
                        )
                    ) BETWEEN 30 AND 37

                THEN 1

                ELSE 0

            END
        ) AS retained_d30

    FROM users u

    LEFT JOIN kyc_applications k
        ON u.user_id = k.user_id

    LEFT JOIN events e
        ON u.user_id = e.user_id

    LEFT JOIN transactions t
        ON u.user_id = t.user_id

    GROUP BY
        u.user_id,
        u.acquisition_channel
)

SELECT

    acquisition_channel,

    COUNT(*) AS acquired_users,

    ROUND(
        100.0 *
        SUM(completed_kyc)
        /
        COUNT(*),
        2
    ) AS kyc_completion_pct,

    ROUND(
        100.0 *
        SUM(activated)
        /
        COUNT(*),
        2
    ) AS activation_rate_pct,

    ROUND(
        100.0 *
        SUM(retained_d30)
        /
        COUNT(*),
        2
    ) AS d30_retention_pct,

    ROUND(

        (
            (
                100.0 *
                SUM(activated)
                /
                COUNT(*)
            ) * 0.40
        )

        +

        (
            (
                100.0 *
                SUM(retained_d30)
                /
                COUNT(*)
            ) * 0.40
        )

        +

        (
            (
                100.0 *
                SUM(completed_kyc)
                /
                COUNT(*)
            ) * 0.20
        ),

        2

    ) AS acquisition_quality_score

FROM user_metrics

GROUP BY
    acquisition_channel;


-- ============================================================
-- VIEW 7: EARLY BEHAVIOR AND D30 RETENTION
-- ============================================================

CREATE OR REPLACE VIEW vw_activation_retention AS

WITH user_behavior AS (

    SELECT

        u.user_id,

        COUNT(
            CASE

                WHEN
                    t.status = 'success'

                    AND t.transaction_timestamp
                        >= u.signup_timestamp

                    AND t.transaction_timestamp
                        < u.signup_timestamp
                        + INTERVAL 7 DAY

                THEN t.transaction_id

            END
        ) AS transactions_first_7d,

        MAX(
            CASE

                WHEN
                    t.status = 'success'

                    AND DATEDIFF(
                        DATE(
                            t.transaction_timestamp
                        ),
                        DATE(
                            u.signup_timestamp
                        )
                    ) BETWEEN 30 AND 37

                THEN 1

                ELSE 0

            END
        ) AS retained_d30

    FROM users u

    LEFT JOIN transactions t
        ON u.user_id = t.user_id

    GROUP BY
        u.user_id
)

SELECT

    CASE

        WHEN transactions_first_7d = 0
            THEN '0 transactions'

        WHEN transactions_first_7d = 1
            THEN '1 transaction'

        WHEN transactions_first_7d = 2
            THEN '2 transactions'

        WHEN transactions_first_7d BETWEEN 3 AND 4
            THEN '3-4 transactions'

        ELSE '5+ transactions'

    END AS early_behavior_group,

    CASE

        WHEN transactions_first_7d = 0
            THEN 1

        WHEN transactions_first_7d = 1
            THEN 2

        WHEN transactions_first_7d = 2
            THEN 3

        WHEN transactions_first_7d BETWEEN 3 AND 4
            THEN 4

        ELSE 5

    END AS group_order,

    COUNT(*) AS users,

    SUM(
        retained_d30
    ) AS retained_d30_users,

    ROUND(
        100.0 *
        SUM(
            retained_d30
        )
        /
        COUNT(*),
        2
    ) AS d30_retention_pct

FROM user_behavior

GROUP BY
    early_behavior_group,
    group_order;


-- ============================================================
-- VIEW 8: MONTHLY COHORT RETENTION MATRIX
-- ============================================================

CREATE OR REPLACE VIEW vw_cohort_retention AS

WITH cohort_sizes AS (

    SELECT

        DATE_FORMAT(
            signup_timestamp,
            '%Y-%m-01'
        ) AS cohort_month,

        COUNT(*) AS cohort_size

    FROM users

    GROUP BY
        DATE_FORMAT(
            signup_timestamp,
            '%Y-%m-01'
        )
),

activity AS (

    SELECT DISTINCT

        u.user_id,

        DATE_FORMAT(
            u.signup_timestamp,
            '%Y-%m-01'
        ) AS cohort_month,

        TIMESTAMPDIFF(

            MONTH,

            STR_TO_DATE(
                DATE_FORMAT(
                    u.signup_timestamp,
                    '%Y-%m-01'
                ),
                '%Y-%m-%d'
            ),

            STR_TO_DATE(
                DATE_FORMAT(
                    t.transaction_timestamp,
                    '%Y-%m-01'
                ),
                '%Y-%m-%d'
            )

        ) AS month_number

    FROM users u

    JOIN transactions t
        ON u.user_id = t.user_id

    WHERE
        t.status = 'success'
),

retention AS (

    SELECT

        cohort_month,

        month_number,

        COUNT(
            DISTINCT user_id
        ) AS retained_users

    FROM activity

    WHERE
        month_number BETWEEN 0 AND 5

    GROUP BY
        cohort_month,
        month_number
)

SELECT

    c.cohort_month,

    c.cohort_size,

    ROUND(
        100.0 *
        MAX(
            CASE
                WHEN r.month_number = 0
                THEN r.retained_users
            END
        )
        /
        c.cohort_size,
        2
    ) AS M0,

    ROUND(
        100.0 *
        MAX(
            CASE
                WHEN r.month_number = 1
                THEN r.retained_users
            END
        )
        /
        c.cohort_size,
        2
    ) AS M1,

    ROUND(
        100.0 *
        MAX(
            CASE
                WHEN r.month_number = 2
                THEN r.retained_users
            END
        )
        /
        c.cohort_size,
        2
    ) AS M2,

    ROUND(
        100.0 *
        MAX(
            CASE
                WHEN r.month_number = 3
                THEN r.retained_users
            END
        )
        /
        c.cohort_size,
        2
    ) AS M3,

    ROUND(
        100.0 *
        MAX(
            CASE
                WHEN r.month_number = 4
                THEN r.retained_users
            END
        )
        /
        c.cohort_size,
        2
    ) AS M4,

    ROUND(
        100.0 *
        MAX(
            CASE
                WHEN r.month_number = 5
                THEN r.retained_users
            END
        )
        /
        c.cohort_size,
        2
    ) AS M5

FROM cohort_sizes c

LEFT JOIN retention r
    ON c.cohort_month =
       r.cohort_month

GROUP BY
    c.cohort_month,
    c.cohort_size;


-- ============================================================
-- VIEW 9: EXPERIMENT SCORECARD
-- ============================================================

CREATE OR REPLACE VIEW vw_experiment_scorecard AS

WITH experiment_users AS (

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
)

SELECT

    variant,

    COUNT(*) AS assigned_users,

    ROUND(
        100.0 *
        SUM(completed_kyc)
        /
        COUNT(*),
        2
    ) AS kyc_completion_rate_pct,

    ROUND(
        100.0 *
        SUM(contacted_support)
        /
        COUNT(*),
        2
    ) AS support_contact_rate_pct,

    ROUND(
        100.0 *
        SUM(activated)
        /
        COUNT(*),
        2
    ) AS activation_rate_pct

FROM experiment_users

GROUP BY
    variant;