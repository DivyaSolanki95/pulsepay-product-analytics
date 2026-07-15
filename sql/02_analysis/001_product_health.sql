USE pulsepay_analytics;

-- ============================================================
-- PULSEPAY PRODUCT ANALYTICS
-- ANALYSIS 01: PRODUCT HEALTH
-- ============================================================
-- Business Question:
-- How healthy is PulsePay and where are users dropping off?
--
-- North Star Metric:
-- Weekly Successful Transacting Users (WSTU)
-- ============================================================


-- ============================================================
-- 1. DATASET OVERVIEW
-- ============================================================

SELECT
    (SELECT COUNT(*) FROM users) AS total_users,
    (SELECT COUNT(*) FROM events) AS total_events,
    (SELECT COUNT(*) FROM transactions) AS total_transactions,
    (SELECT COUNT(*) FROM kyc_applications) AS total_kyc_applications,
    (SELECT COUNT(*) FROM support_tickets) AS total_support_tickets;


-- ============================================================
-- 2. USER ACQUISITION BY CHANNEL
-- ============================================================

SELECT
    acquisition_channel,
    COUNT(*) AS total_users,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS user_share_pct
FROM users
GROUP BY acquisition_channel
ORDER BY total_users DESC;


-- ============================================================
-- 3. MONTHLY USER GROWTH
-- ============================================================

SELECT
    DATE_FORMAT(signup_timestamp, '%Y-%m') AS signup_month,
    COUNT(*) AS new_users
FROM users
GROUP BY DATE_FORMAT(signup_timestamp, '%Y-%m')
ORDER BY signup_month;


-- ============================================================
-- 4. OVERALL ONBOARDING FUNNEL
-- ============================================================

WITH funnel AS (

    SELECT
        COUNT(DISTINCT user_id) AS account_created,

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
                WHEN event_name = 'first_successful_transaction'
                THEN user_id
            END
        ) AS first_successful_transaction

    FROM events
)

SELECT
    account_created,
    otp_verified,
    kyc_started,
    kyc_completed,
    bank_linked,
    first_successful_transaction,

    ROUND(
        100.0 * otp_verified /
        NULLIF(account_created, 0),
        2
    ) AS signup_to_otp_pct,

    ROUND(
        100.0 * kyc_started /
        NULLIF(otp_verified, 0),
        2
    ) AS otp_to_kyc_start_pct,

    ROUND(
        100.0 * kyc_completed /
        NULLIF(kyc_started, 0),
        2
    ) AS kyc_completion_pct,

    ROUND(
        100.0 * bank_linked /
        NULLIF(kyc_completed, 0),
        2
    ) AS bank_link_rate_pct,

    ROUND(
        100.0 * first_successful_transaction /
        NULLIF(bank_linked, 0),
        2
    ) AS bank_to_first_transaction_pct,

    ROUND(
        100.0 * first_successful_transaction /
        NULLIF(account_created, 0),
        2
    ) AS overall_activation_pct

FROM funnel;


-- ============================================================
-- 5. TRANSACTION HEALTH
-- ============================================================

SELECT
    status,
    COUNT(*) AS transaction_count,

    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS transaction_share_pct

FROM transactions

GROUP BY status

ORDER BY transaction_count DESC;


-- ============================================================
-- 6. NORTH STAR METRIC
-- WEEKLY SUCCESSFUL TRANSACTING USERS
-- ============================================================

SELECT
    YEARWEEK(
        transaction_timestamp,
        3
    ) AS iso_year_week,

    DATE(
        transaction_timestamp
        - INTERVAL WEEKDAY(transaction_timestamp) DAY
    ) AS week_start,

    COUNT(
        DISTINCT user_id
    ) AS weekly_successful_transacting_users

FROM transactions

WHERE status = 'success'

GROUP BY
    YEARWEEK(transaction_timestamp, 3),
    DATE(
        transaction_timestamp
        - INTERVAL WEEKDAY(transaction_timestamp) DAY
    )

ORDER BY week_start;


-- ============================================================
-- 7. TRANSACTION SUCCESS RATE BY MONTH
-- ============================================================

SELECT
    DATE_FORMAT(
        transaction_timestamp,
        '%Y-%m'
    ) AS transaction_month,

    COUNT(*) AS total_transactions,

    SUM(
        status = 'success'
    ) AS successful_transactions,

    ROUND(
        100.0 *
        SUM(status = 'success') /
        COUNT(*),
        2
    ) AS transaction_success_rate_pct

FROM transactions

GROUP BY
    DATE_FORMAT(
        transaction_timestamp,
        '%Y-%m'
    )

ORDER BY transaction_month;


-- ============================================================
-- 8. KYC HEALTH
-- ============================================================

SELECT
    status,
    COUNT(*) AS applications,

    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS application_share_pct

FROM kyc_applications

GROUP BY status

ORDER BY applications DESC;


-- ============================================================
-- 9. DEVICE DISTRIBUTION
-- ============================================================

SELECT
    device_type,
    COUNT(*) AS users,

    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS user_share_pct

FROM users

GROUP BY device_type

ORDER BY users DESC;


-- ============================================================
-- 10. INITIAL PRODUCT HEALTH SUMMARY
-- ============================================================

SELECT

    COUNT(
        DISTINCT u.user_id
    ) AS registered_users,

    COUNT(
        DISTINCT CASE
            WHEN k.status = 'completed'
            THEN u.user_id
        END
    ) AS kyc_completed_users,

    COUNT(
        DISTINCT CASE
            WHEN t.status = 'success'
            THEN u.user_id
        END
    ) AS successful_transacting_users,

    ROUND(
        100.0 *
        COUNT(
            DISTINCT CASE
                WHEN t.status = 'success'
                THEN u.user_id
            END
        )
        /
        COUNT(
            DISTINCT u.user_id
        ),
        2
    ) AS successful_transactor_rate_pct

FROM users u

LEFT JOIN kyc_applications k
    ON u.user_id = k.user_id

LEFT JOIN transactions t
    ON u.user_id = t.user_id;