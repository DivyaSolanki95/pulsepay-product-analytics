USE pulsepay_analytics;

-- ============================================================
-- PULSEPAY PRODUCT ANALYTICS
-- ANALYSIS 06: ACQUISITION QUALITY
-- ============================================================
--
-- Business Questions:
--
-- 1. Which channels bring the most users?
-- 2. Which channels produce the highest KYC completion?
-- 3. Which channels produce the highest activation?
-- 4. Which channels produce the best D30 retention?
-- 5. Which campaigns generate high-quality users?
--
-- Core Principle:
-- Acquisition volume != Acquisition quality
--
-- ============================================================


-- ============================================================
-- 1. ACQUISITION VOLUME
-- ============================================================

SELECT

    acquisition_channel,

    COUNT(*) AS acquired_users,

    ROUND(
        100.0 *
        COUNT(*)
        /
        SUM(COUNT(*)) OVER (),
        2
    ) AS acquisition_share_pct

FROM users

GROUP BY
    acquisition_channel

ORDER BY
    acquired_users DESC;


-- ============================================================
-- 2. KYC COMPLETION BY ACQUISITION CHANNEL
-- ============================================================

WITH kyc_users AS (

    SELECT

        u.user_id,
        u.acquisition_channel,

        MAX(
            k.status = 'completed'
        ) AS completed_kyc

    FROM users u

    LEFT JOIN kyc_applications k
        ON u.user_id = k.user_id

    GROUP BY
        u.user_id,
        u.acquisition_channel
)

SELECT

    acquisition_channel,

    COUNT(*) AS acquired_users,

    SUM(completed_kyc) AS kyc_completed_users,

    ROUND(
        100.0 *
        SUM(completed_kyc)
        /
        COUNT(*),
        2
    ) AS signup_to_kyc_completion_pct

FROM kyc_users

GROUP BY
    acquisition_channel

ORDER BY
    signup_to_kyc_completion_pct DESC;


-- ============================================================
-- 3. ACTIVATION RATE BY ACQUISITION CHANNEL
-- ============================================================

WITH activated_users AS (

    SELECT DISTINCT
        user_id

    FROM events

    WHERE
        event_name =
        'first_successful_transaction'
)

SELECT

    u.acquisition_channel,

    COUNT(
        DISTINCT u.user_id
    ) AS acquired_users,

    COUNT(
        DISTINCT a.user_id
    ) AS activated_users,

    ROUND(
        100.0 *
        COUNT(
            DISTINCT a.user_id
        )
        /
        COUNT(
            DISTINCT u.user_id
        ),
        2
    ) AS activation_rate_pct

FROM users u

LEFT JOIN activated_users a
    ON u.user_id = a.user_id

GROUP BY
    u.acquisition_channel

ORDER BY
    activation_rate_pct DESC;


-- ============================================================
-- 4. D30 RETENTION BY ACQUISITION CHANNEL
-- ============================================================

WITH user_retention AS (

    SELECT

        u.user_id,

        u.acquisition_channel,

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
        u.user_id,
        u.acquisition_channel
)

SELECT

    acquisition_channel,

    COUNT(*) AS acquired_users,

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

FROM user_retention

GROUP BY
    acquisition_channel

ORDER BY
    d30_retention_pct DESC;


-- ============================================================
-- 5. ACTIVATION MILESTONE RATE BY CHANNEL
-- ============================================================
--
-- Milestone:
-- 3+ successful transactions in first 7 days
--
-- ============================================================

WITH early_behavior AS (

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
        ) AS successful_transactions_first_7d

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

    SUM(
        successful_transactions_first_7d >= 3
    ) AS users_reaching_milestone,

    ROUND(
        100.0 *
        SUM(
            successful_transactions_first_7d >= 3
        )
        /
        COUNT(*),
        2
    ) AS milestone_rate_pct

FROM early_behavior

GROUP BY
    acquisition_channel

ORDER BY
    milestone_rate_pct DESC;


-- ============================================================
-- 6. TRANSACTION VALUE BY ACQUISITION CHANNEL
-- ============================================================

SELECT

    u.acquisition_channel,

    COUNT(
        DISTINCT u.user_id
    ) AS acquired_users,

    COUNT(
        DISTINCT CASE
            WHEN t.status = 'success'
            THEN t.user_id
        END
    ) AS successful_transactors,

    COUNT(
        CASE
            WHEN t.status = 'success'
            THEN t.transaction_id
        END
    ) AS successful_transactions,

    ROUND(
        SUM(
            CASE
                WHEN t.status = 'success'
                THEN t.amount
                ELSE 0
            END
        ),
        2
    ) AS total_successful_transaction_value,

    ROUND(
        AVG(
            CASE
                WHEN t.status = 'success'
                THEN t.amount
            END
        ),
        2
    ) AS avg_successful_transaction_value

FROM users u

LEFT JOIN transactions t
    ON u.user_id = t.user_id

GROUP BY
    u.acquisition_channel

ORDER BY
    total_successful_transaction_value DESC;


-- ============================================================
-- 7. CAMPAIGN-LEVEL QUALITY
-- ============================================================

WITH campaign_performance AS (

    SELECT

        u.user_id,

        u.acquisition_channel,

        u.campaign_name,

        MAX(
            CASE
                WHEN e.event_name =
                'first_successful_transaction'
                THEN 1
                ELSE 0
            END
        ) AS activated

    FROM users u

    LEFT JOIN events e
        ON u.user_id = e.user_id

    GROUP BY
        u.user_id,
        u.acquisition_channel,
        u.campaign_name
)

SELECT

    acquisition_channel,

    campaign_name,

    COUNT(*) AS acquired_users,

    SUM(
        activated
    ) AS activated_users,

    ROUND(
        100.0 *
        SUM(
            activated
        )
        /
        COUNT(*),
        2
    ) AS activation_rate_pct

FROM campaign_performance

GROUP BY
    acquisition_channel,
    campaign_name

ORDER BY
    activation_rate_pct DESC;


-- ============================================================
-- 8. COMPLETE CHANNEL QUALITY SCORECARD
-- ============================================================
--
-- Dashboard-ready acquisition table.
--
-- ============================================================

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
    ) AS d30_retention_pct

FROM user_metrics

GROUP BY
    acquisition_channel

ORDER BY
    d30_retention_pct DESC;


-- ============================================================
-- 9. ACQUISITION EFFICIENCY RANKING
-- ============================================================
--
-- This is a relative quality index.
-- It combines:
--
-- 40% Activation Rate
-- 40% D30 Retention
-- 20% KYC Completion
--
-- This is NOT a universal formula.
-- The weighting represents a product prioritization choice.
--
-- ============================================================

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
),

channel_metrics AS (

    SELECT

        acquisition_channel,

        COUNT(*) AS acquired_users,

        100.0 *
        SUM(completed_kyc)
        /
        COUNT(*) AS kyc_rate,

        100.0 *
        SUM(activated)
        /
        COUNT(*) AS activation_rate,

        100.0 *
        SUM(retained_d30)
        /
        COUNT(*) AS retention_rate

    FROM user_metrics

    GROUP BY
        acquisition_channel
)

SELECT

    acquisition_channel,

    acquired_users,

    ROUND(
        kyc_rate,
        2
    ) AS kyc_completion_pct,

    ROUND(
        activation_rate,
        2
    ) AS activation_rate_pct,

    ROUND(
        retention_rate,
        2
    ) AS d30_retention_pct,

    ROUND(

        (
            activation_rate * 0.40
        )

        +

        (
            retention_rate * 0.40
        )

        +

        (
            kyc_rate * 0.20
        ),

        2

    ) AS acquisition_quality_score

FROM channel_metrics

ORDER BY
    acquisition_quality_score DESC;