USE pulsepay_analytics;

-- ============================================================
-- PULSEPAY PRODUCT ANALYTICS
-- ANALYSIS 04: RETENTION & ACTIVATION MILESTONE
-- ============================================================
--
-- Business Questions:
--
-- 1. How many users return after signup?
-- 2. What is D1, D7 and D30 retention?
-- 3. Does completing more transactions early predict retention?
-- 4. What should PulsePay define as its activation milestone?
--
-- Retention definition:
-- A user is considered active if they complete at least one
-- successful transaction during the target retention window.
--
-- ============================================================


-- ============================================================
-- 1. USER-LEVEL RETENTION FLAGS
-- ============================================================

WITH successful_transactions AS (

    SELECT
        user_id,
        transaction_timestamp

    FROM transactions

    WHERE
        status = 'success'
),

retention_flags AS (

    SELECT

        u.user_id,
        DATE(u.signup_timestamp) AS signup_date,

        MAX(
            CASE
                WHEN DATEDIFF(
                    DATE(t.transaction_timestamp),
                    DATE(u.signup_timestamp)
                ) = 1
                THEN 1
                ELSE 0
            END
        ) AS retained_d1,

        MAX(
            CASE
                WHEN DATEDIFF(
                    DATE(t.transaction_timestamp),
                    DATE(u.signup_timestamp)
                ) BETWEEN 7 AND 13
                THEN 1
                ELSE 0
            END
        ) AS retained_d7,

        MAX(
            CASE
                WHEN DATEDIFF(
                    DATE(t.transaction_timestamp),
                    DATE(u.signup_timestamp)
                ) BETWEEN 30 AND 37
                THEN 1
                ELSE 0
            END
        ) AS retained_d30

    FROM users u

    LEFT JOIN successful_transactions t
        ON u.user_id = t.user_id

    GROUP BY
        u.user_id,
        DATE(u.signup_timestamp)
)

SELECT

    COUNT(*) AS total_users,

    SUM(retained_d1) AS retained_d1_users,

    SUM(retained_d7) AS retained_d7_users,

    SUM(retained_d30) AS retained_d30_users,

    ROUND(
        100.0 * SUM(retained_d1) / COUNT(*),
        2
    ) AS d1_retention_pct,

    ROUND(
        100.0 * SUM(retained_d7) / COUNT(*),
        2
    ) AS d7_retention_pct,

    ROUND(
        100.0 * SUM(retained_d30) / COUNT(*),
        2
    ) AS d30_retention_pct

FROM retention_flags;


-- ============================================================
-- 2. RETENTION AMONG USERS WHO COMPLETED KYC
-- ============================================================

WITH completed_kyc AS (

    SELECT DISTINCT
        user_id

    FROM kyc_applications

    WHERE
        status = 'completed'
),

retention_flags AS (

    SELECT

        u.user_id,

        MAX(
            CASE
                WHEN
                    t.status = 'success'

                    AND DATEDIFF(
                        DATE(t.transaction_timestamp),
                        DATE(u.signup_timestamp)
                    ) BETWEEN 7 AND 13

                THEN 1
                ELSE 0
            END
        ) AS retained_d7,

        MAX(
            CASE
                WHEN
                    t.status = 'success'

                    AND DATEDIFF(
                        DATE(t.transaction_timestamp),
                        DATE(u.signup_timestamp)
                    ) BETWEEN 30 AND 37

                THEN 1
                ELSE 0
            END
        ) AS retained_d30

    FROM users u

    JOIN completed_kyc k
        ON u.user_id = k.user_id

    LEFT JOIN transactions t
        ON u.user_id = t.user_id

    GROUP BY
        u.user_id
)

SELECT

    COUNT(*) AS completed_kyc_users,

    ROUND(
        100.0 *
        SUM(retained_d7)
        /
        COUNT(*),
        2
    ) AS d7_retention_pct,

    ROUND(
        100.0 *
        SUM(retained_d30)
        /
        COUNT(*),
        2
    ) AS d30_retention_pct

FROM retention_flags;


-- ============================================================
-- 3. FIRST 7-DAY TRANSACTION BEHAVIOR
-- ============================================================

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
    ) AS successful_transactions_first_7d

FROM users u

LEFT JOIN transactions t
    ON u.user_id = t.user_id

GROUP BY
    u.user_id

ORDER BY
    successful_transactions_first_7d DESC

LIMIT 100;


-- ============================================================
-- 4. EARLY TRANSACTION BEHAVIOR VS D30 RETENTION
-- ============================================================

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
                        DATE(t.transaction_timestamp),
                        DATE(u.signup_timestamp)
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
),

behavior_groups AS (

    SELECT

        user_id,

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

        retained_d30

    FROM user_behavior
)

SELECT

    early_behavior_group,

    COUNT(*) AS users,

    SUM(retained_d30) AS retained_d30_users,

    ROUND(
        100.0 *
        SUM(retained_d30)
        /
        COUNT(*),
        2
    ) AS d30_retention_pct

FROM behavior_groups

GROUP BY
    early_behavior_group

ORDER BY

    CASE early_behavior_group

        WHEN '0 transactions'
            THEN 1

        WHEN '1 transaction'
            THEN 2

        WHEN '2 transactions'
            THEN 3

        WHEN '3-4 transactions'
            THEN 4

        WHEN '5+ transactions'
            THEN 5

    END;


-- ============================================================
-- 5. ACTIVATION MILESTONE TEST
-- ============================================================
--
-- Question:
-- Does reaching 3 successful transactions in the first
-- 7 days correlate with stronger D30 retention?
--
-- ============================================================

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
                        DATE(t.transaction_timestamp),
                        DATE(u.signup_timestamp)
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

        WHEN transactions_first_7d >= 3
            THEN 'Reached activation milestone'

        ELSE 'Did not reach activation milestone'

    END AS activation_segment,

    COUNT(*) AS users,

    SUM(retained_d30) AS retained_d30_users,

    ROUND(
        100.0 *
        SUM(retained_d30)
        /
        COUNT(*),
        2
    ) AS d30_retention_pct

FROM user_behavior

GROUP BY
    activation_segment

ORDER BY
    d30_retention_pct DESC;


-- ============================================================
-- 6. RETENTION BY ACQUISITION CHANNEL
-- ============================================================

WITH retention_flags AS (

    SELECT

        u.user_id,
        u.acquisition_channel,

        MAX(
            CASE
                WHEN
                    t.status = 'success'

                    AND DATEDIFF(
                        DATE(t.transaction_timestamp),
                        DATE(u.signup_timestamp)
                    ) BETWEEN 30 AND 37

                THEN 1
                ELSE 0
            END
        ) AS retained_d30

    FROM users u

    LEFT JOIN transactions t
        ON u.user_id = t.user_id

    GROUP BY
        u.user_id,
        u.acquisition_channel
)

SELECT

    acquisition_channel,

    COUNT(*) AS acquired_users,

    SUM(retained_d30) AS retained_d30_users,

    ROUND(
        100.0 *
        SUM(retained_d30)
        /
        COUNT(*),
        2
    ) AS d30_retention_pct

FROM retention_flags

GROUP BY
    acquisition_channel

ORDER BY
    d30_retention_pct DESC;


-- ============================================================
-- 7. RETENTION BY DEVICE
-- ============================================================

WITH retention_flags AS (

    SELECT

        u.user_id,
        u.device_type,

        MAX(
            CASE
                WHEN
                    t.status = 'success'

                    AND DATEDIFF(
                        DATE(t.transaction_timestamp),
                        DATE(u.signup_timestamp)
                    ) BETWEEN 30 AND 37

                THEN 1
                ELSE 0
            END
        ) AS retained_d30

    FROM users u

    LEFT JOIN transactions t
        ON u.user_id = t.user_id

    GROUP BY
        u.user_id,
        u.device_type
)

SELECT

    device_type,

    COUNT(*) AS users,

    SUM(retained_d30) AS retained_d30_users,

    ROUND(
        100.0 *
        SUM(retained_d30)
        /
        COUNT(*),
        2
    ) AS d30_retention_pct

FROM retention_flags

GROUP BY
    device_type

ORDER BY
    d30_retention_pct DESC;


-- ============================================================
-- 8. ACTIVATION MILESTONE BY ACQUISITION CHANNEL
-- ============================================================

WITH user_behavior AS (

    SELECT

        u.user_id,
        u.acquisition_channel,

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
        ) AS transactions_first_7d

    FROM users u

    LEFT JOIN transactions t
        ON u.user_id = t.user_id

    GROUP BY
        u.user_id,
        u.acquisition_channel
)

SELECT

    acquisition_channel,

    COUNT(*) AS users,

    SUM(
        transactions_first_7d >= 3
    ) AS users_reaching_milestone,

    ROUND(
        100.0 *
        SUM(
            transactions_first_7d >= 3
        )
        /
        COUNT(*),
        2
    ) AS milestone_rate_pct

FROM user_behavior

GROUP BY
    acquisition_channel

ORDER BY
    milestone_rate_pct DESC;


-- ============================================================
-- 9. PRODUCT RECOMMENDATION EVIDENCE TABLE
-- ============================================================
--
-- This result is designed for the final case study.
--
-- ============================================================

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
                        DATE(t.transaction_timestamp),
                        DATE(u.signup_timestamp)
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

        WHEN transactions_first_7d >= 3
            THEN '3+ successful transactions in first 7 days'

        ELSE 'Fewer than 3 successful transactions in first 7 days'

    END AS user_segment,

    COUNT(*) AS users,

    SUM(retained_d30) AS retained_users,

    ROUND(
        100.0 *
        SUM(retained_d30)
        /
        COUNT(*),
        2
    ) AS d30_retention_pct

FROM user_behavior

GROUP BY
    user_segment

ORDER BY
    d30_retention_pct DESC;