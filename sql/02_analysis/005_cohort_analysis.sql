USE pulsepay_analytics;

-- ============================================================
-- PULSEPAY PRODUCT ANALYTICS
-- ANALYSIS 05: COHORT RETENTION ANALYSIS
-- ============================================================
--
-- Business Question:
-- How does user retention change over time for different
-- signup cohorts?
--
-- Cohort:
-- Month in which the user signed up.
--
-- Activity:
-- At least one successful transaction in a calendar month.
--
-- ============================================================


-- ============================================================
-- 1. MONTHLY SIGNUP COHORT SIZE
-- ============================================================

SELECT
    DATE_FORMAT(
        signup_timestamp,
        '%Y-%m'
    ) AS cohort_month,

    COUNT(*) AS cohort_size

FROM users

GROUP BY
    DATE_FORMAT(
        signup_timestamp,
        '%Y-%m'
    )

ORDER BY cohort_month;


-- ============================================================
-- 2. USER ACTIVITY BY COHORT AND ACTIVITY MONTH
-- ============================================================

WITH user_activity AS (

    SELECT DISTINCT
        u.user_id,

        DATE_FORMAT(
            u.signup_timestamp,
            '%Y-%m'
        ) AS cohort_month,

        DATE_FORMAT(
            t.transaction_timestamp,
            '%Y-%m'
        ) AS activity_month

    FROM users u

    JOIN transactions t
        ON u.user_id = t.user_id

    WHERE
        t.status = 'success'
)

SELECT
    cohort_month,
    activity_month,

    COUNT(
        DISTINCT user_id
    ) AS active_users

FROM user_activity

GROUP BY
    cohort_month,
    activity_month

ORDER BY
    cohort_month,
    activity_month;


-- ============================================================
-- 3. COHORT RETENTION BY MONTH NUMBER
-- ============================================================

WITH cohort_activity AS (

    SELECT DISTINCT

        u.user_id,

        DATE_FORMAT(
            u.signup_timestamp,
            '%Y-%m-01'
        ) AS cohort_month,

        DATE_FORMAT(
            t.transaction_timestamp,
            '%Y-%m-01'
        ) AS activity_month

    FROM users u

    JOIN transactions t
        ON u.user_id = t.user_id

    WHERE
        t.status = 'success'
),

cohort_index AS (

    SELECT

        user_id,

        cohort_month,

        activity_month,

        TIMESTAMPDIFF(
            MONTH,
            STR_TO_DATE(
                cohort_month,
                '%Y-%m-%d'
            ),
            STR_TO_DATE(
                activity_month,
                '%Y-%m-%d'
            )
        ) AS month_number

    FROM cohort_activity
)

SELECT

    cohort_month,

    month_number,

    COUNT(
        DISTINCT user_id
    ) AS active_users

FROM cohort_index

WHERE
    month_number >= 0

GROUP BY
    cohort_month,
    month_number

ORDER BY
    cohort_month,
    month_number;


-- ============================================================
-- 4. TRUE COHORT RETENTION RATE
-- ============================================================
--
-- Denominator:
-- Total number of users in each signup cohort.
--
-- Numerator:
-- Users with at least one successful transaction during
-- the relevant activity month.
--
-- ============================================================

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

cohort_activity AS (

    SELECT DISTINCT

        u.user_id,

        DATE_FORMAT(
            u.signup_timestamp,
            '%Y-%m-01'
        ) AS cohort_month,

        DATE_FORMAT(
            t.transaction_timestamp,
            '%Y-%m-01'
        ) AS activity_month

    FROM users u

    JOIN transactions t
        ON u.user_id = t.user_id

    WHERE
        t.status = 'success'
),

indexed_activity AS (

    SELECT

        user_id,

        cohort_month,

        TIMESTAMPDIFF(
            MONTH,
            STR_TO_DATE(
                cohort_month,
                '%Y-%m-%d'
            ),
            STR_TO_DATE(
                activity_month,
                '%Y-%m-%d'
            )
        ) AS month_number

    FROM cohort_activity
),

retained_users AS (

    SELECT

        cohort_month,

        month_number,

        COUNT(
            DISTINCT user_id
        ) AS retained_users

    FROM indexed_activity

    WHERE
        month_number >= 0

    GROUP BY
        cohort_month,
        month_number
)

SELECT

    r.cohort_month,

    c.cohort_size,

    r.month_number,

    r.retained_users,

    ROUND(
        100.0 *
        r.retained_users
        /
        c.cohort_size,
        2
    ) AS retention_rate_pct

FROM retained_users r

JOIN cohort_sizes c
    ON r.cohort_month =
       c.cohort_month

ORDER BY
    r.cohort_month,
    r.month_number;


-- ============================================================
-- 5. COHORT RETENTION MATRIX
-- ============================================================
--
-- Dashboard-ready format.
--
-- M0 = Signup month
-- M1 = Month after signup
-- M2 = Two months after signup
-- etc.
--
-- ============================================================

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
    c.cohort_size

ORDER BY
    c.cohort_month;