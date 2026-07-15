USE pulsepay_analytics;

-- ============================================================
-- PULSEPAY PRODUCT ANALYTICS
-- EXPERIMENT 01: KYC FLOW SIMPLIFICATION
-- ============================================================
--
-- Experiment:
-- Control   = Existing 5-step KYC flow
-- Treatment = Simplified 3-step KYC flow
--
-- Primary Metric:
-- KYC Completion Rate
--
-- Guardrail Metric:
-- Support Contact Rate
--
-- Analytical principle:
-- Validate experiment setup BEFORE interpreting results.
--
-- ============================================================


-- ============================================================
-- 1. EXPERIMENT DEFINITION
-- ============================================================

SELECT
    experiment_id,
    experiment_name,
    hypothesis,
    primary_metric,
    guardrail_metric,
    start_date,
    end_date,
    status

FROM experiments

WHERE
    experiment_id = 1;


-- ============================================================
-- 2. SAMPLE SIZE BY VARIANT
-- ============================================================

SELECT
    variant,

    COUNT(
        DISTINCT user_id
    ) AS assigned_users,

    ROUND(
        100.0 *
        COUNT(DISTINCT user_id)
        /
        SUM(
            COUNT(DISTINCT user_id)
        ) OVER (),
        2
    ) AS allocation_pct

FROM experiment_assignments

WHERE
    experiment_id = 1

GROUP BY
    variant;


-- ============================================================
-- 3. SAMPLE RATIO MISMATCH CHECK
-- ============================================================
--
-- Expected allocation:
-- 50% Control
-- 50% Treatment
--
-- This query provides a quick descriptive check.
-- Formal significance testing will be done in Python.
--
-- ============================================================

WITH allocation AS (

    SELECT
        variant,
        COUNT(*) AS users

    FROM experiment_assignments

    WHERE
        experiment_id = 1

    GROUP BY
        variant
),

totals AS (

    SELECT
        SUM(users) AS total_users

    FROM allocation
)

SELECT
    a.variant,
    a.users,

    ROUND(
        100.0 *
        a.users /
        t.total_users,
        2
    ) AS observed_allocation_pct,

    50.00 AS expected_allocation_pct,

    ROUND(
        (
            100.0 *
            a.users /
            t.total_users
        ) - 50.00,
        2
    ) AS deviation_percentage_points

FROM allocation a

CROSS JOIN totals t;


-- ============================================================
-- 4. CHECK ASSIGNMENT TIMING
-- ============================================================

SELECT
    MIN(assigned_at) AS first_assignment,
    MAX(assigned_at) AS last_assignment,
    COUNT(*) AS total_assignments

FROM experiment_assignments

WHERE
    experiment_id = 1;


-- ============================================================
-- 5. CHECK FOR DUPLICATE ASSIGNMENTS
-- ============================================================

SELECT
    experiment_id,
    user_id,
    COUNT(*) AS assignment_count

FROM experiment_assignments

WHERE
    experiment_id = 1

GROUP BY
    experiment_id,
    user_id

HAVING
    COUNT(*) > 1;


-- ============================================================
-- 6. KYC START RATE BY VARIANT
-- ============================================================
--
-- This helps identify whether assignment groups differ before
-- reaching the KYC completion outcome.
--
-- ============================================================

WITH user_outcomes AS (

    SELECT

        ea.user_id,
        ea.variant,

        MAX(
            CASE
                WHEN k.user_id IS NOT NULL
                THEN 1
                ELSE 0
            END
        ) AS started_kyc

    FROM experiment_assignments ea

    LEFT JOIN kyc_applications k
        ON ea.user_id = k.user_id

    WHERE
        ea.experiment_id = 1

    GROUP BY
        ea.user_id,
        ea.variant
)

SELECT
    variant,

    COUNT(*) AS assigned_users,

    SUM(
        started_kyc
    ) AS users_starting_kyc,

    ROUND(
        100.0 *
        SUM(started_kyc)
        /
        COUNT(*),
        2
    ) AS kyc_start_rate_pct

FROM user_outcomes

GROUP BY
    variant;


-- ============================================================
-- 7. PRIMARY METRIC:
-- KYC COMPLETION RATE AMONG ASSIGNED USERS
-- ============================================================

WITH user_outcomes AS (

    SELECT

        ea.user_id,
        ea.variant,

        MAX(
            CASE
                WHEN k.status = 'completed'
                THEN 1
                ELSE 0
            END
        ) AS completed_kyc

    FROM experiment_assignments ea

    LEFT JOIN kyc_applications k
        ON ea.user_id = k.user_id

    WHERE
        ea.experiment_id = 1

    GROUP BY
        ea.user_id,
        ea.variant
)

SELECT
    variant,

    COUNT(*) AS assigned_users,

    SUM(
        completed_kyc
    ) AS completed_kyc_users,

    ROUND(
        100.0 *
        SUM(completed_kyc)
        /
        COUNT(*),
        2
    ) AS kyc_completion_rate_pct

FROM user_outcomes

GROUP BY
    variant;


-- ============================================================
-- 8. PRIMARY METRIC:
-- COMPLETION AMONG USERS WHO STARTED KYC
-- ============================================================

WITH user_outcomes AS (

    SELECT

        ea.user_id,
        ea.variant,

        MAX(
            CASE
                WHEN k.user_id IS NOT NULL
                THEN 1
                ELSE 0
            END
        ) AS started_kyc,

        MAX(
            CASE
                WHEN k.status = 'completed'
                THEN 1
                ELSE 0
            END
        ) AS completed_kyc

    FROM experiment_assignments ea

    LEFT JOIN kyc_applications k
        ON ea.user_id = k.user_id

    WHERE
        ea.experiment_id = 1

    GROUP BY
        ea.user_id,
        ea.variant
)

SELECT
    variant,

    SUM(
        started_kyc
    ) AS users_starting_kyc,

    SUM(
        completed_kyc
    ) AS users_completing_kyc,

    ROUND(
        100.0 *
        SUM(completed_kyc)
        /
        NULLIF(
            SUM(started_kyc),
            0
        ),
        2
    ) AS completion_rate_among_starters_pct

FROM user_outcomes

GROUP BY
    variant;


-- ============================================================
-- 9. ABSOLUTE AND RELATIVE LIFT
-- ============================================================

WITH user_outcomes AS (

    SELECT

        ea.user_id,
        ea.variant,

        MAX(
            CASE
                WHEN k.status = 'completed'
                THEN 1
                ELSE 0
            END
        ) AS completed_kyc

    FROM experiment_assignments ea

    LEFT JOIN kyc_applications k
        ON ea.user_id = k.user_id

    WHERE
        ea.experiment_id = 1

    GROUP BY
        ea.user_id,
        ea.variant
),

variant_rates AS (

    SELECT

        variant,

        1.0 *
        SUM(completed_kyc)
        /
        COUNT(*) AS completion_rate

    FROM user_outcomes

    GROUP BY
        variant
),

pivoted AS (

    SELECT

        MAX(
            CASE
                WHEN variant = 'control'
                THEN completion_rate
            END
        ) AS control_rate,

        MAX(
            CASE
                WHEN variant = 'treatment'
                THEN completion_rate
            END
        ) AS treatment_rate

    FROM variant_rates
)

SELECT

    ROUND(
        control_rate * 100,
        2
    ) AS control_rate_pct,

    ROUND(
        treatment_rate * 100,
        2
    ) AS treatment_rate_pct,

    ROUND(
        (
            treatment_rate
            -
            control_rate
        ) * 100,
        2
    ) AS absolute_lift_percentage_points,

    ROUND(
        100.0 *
        (
            treatment_rate
            -
            control_rate
        )
        /
        NULLIF(
            control_rate,
            0
        ),
        2
    ) AS relative_lift_pct

FROM pivoted;


-- ============================================================
-- 10. GUARDRAIL METRIC:
-- SUPPORT CONTACT RATE
-- ============================================================

WITH support_outcomes AS (

    SELECT

        ea.user_id,
        ea.variant,

        MAX(
            CASE
                WHEN s.ticket_id IS NOT NULL
                THEN 1
                ELSE 0
            END
        ) AS contacted_support

    FROM experiment_assignments ea

    LEFT JOIN support_tickets s
        ON ea.user_id = s.user_id

    WHERE
        ea.experiment_id = 1

    GROUP BY
        ea.user_id,
        ea.variant
)

SELECT
    variant,

    COUNT(*) AS assigned_users,

    SUM(
        contacted_support
    ) AS users_contacting_support,

    ROUND(
        100.0 *
        SUM(contacted_support)
        /
        COUNT(*),
        2
    ) AS support_contact_rate_pct

FROM support_outcomes

GROUP BY
    variant;


-- ============================================================
-- 11. DOWNSTREAM ACTIVATION BY VARIANT
-- ============================================================

WITH activation_outcomes AS (

    SELECT

        ea.user_id,
        ea.variant,

        MAX(
            CASE
                WHEN e.event_name =
                'first_successful_transaction'
                THEN 1
                ELSE 0
            END
        ) AS activated

    FROM experiment_assignments ea

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

    SUM(
        activated
    ) AS activated_users,

    ROUND(
        100.0 *
        SUM(activated)
        /
        COUNT(*),
        2
    ) AS activation_rate_pct

FROM activation_outcomes

GROUP BY
    variant;


-- ============================================================
-- 12. FINAL EXPERIMENT SCORECARD
-- ============================================================

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