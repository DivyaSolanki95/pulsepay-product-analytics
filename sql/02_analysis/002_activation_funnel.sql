USE pulsepay_analytics;

-- ============================================================
-- PULSEPAY PRODUCT ANALYTICS
-- ANALYSIS 02: ACTIVATION FUNNEL
-- ============================================================
-- Goal:
-- Identify which segments have the biggest onboarding and
-- activation problems.
-- ============================================================


-- ============================================================
-- 1. OVERALL FUNNEL BY DEVICE
-- ============================================================

WITH user_funnel AS (

    SELECT
        u.user_id,
        u.device_type,

        MAX(e.event_name = 'otp_verified') AS otp_verified,
        MAX(e.event_name = 'kyc_started') AS kyc_started,
        MAX(e.event_name = 'kyc_completed') AS kyc_completed,
        MAX(e.event_name = 'bank_linked') AS bank_linked,
        MAX(
            e.event_name = 'first_successful_transaction'
        ) AS activated

    FROM users u

    LEFT JOIN events e
        ON u.user_id = e.user_id

    GROUP BY
        u.user_id,
        u.device_type
)

SELECT
    device_type,

    COUNT(*) AS registered_users,

    SUM(otp_verified) AS otp_verified_users,

    SUM(kyc_started) AS kyc_started_users,

    SUM(kyc_completed) AS kyc_completed_users,

    SUM(bank_linked) AS bank_linked_users,

    SUM(activated) AS activated_users,

    ROUND(
        100.0 * SUM(kyc_completed)
        / NULLIF(SUM(kyc_started), 0),
        2
    ) AS kyc_completion_rate_pct,

    ROUND(
        100.0 * SUM(activated)
        / NULLIF(COUNT(*), 0),
        2
    ) AS overall_activation_rate_pct

FROM user_funnel

GROUP BY device_type

ORDER BY overall_activation_rate_pct DESC;


-- ============================================================
-- 2. KYC COMPLETION BY APP VERSION
-- ============================================================

SELECT
    u.device_type,
    u.signup_app_version,

    COUNT(*) AS kyc_started,

    SUM(
        k.status = 'completed'
    ) AS kyc_completed,

    SUM(
        k.status = 'failed'
    ) AS kyc_failed,

    SUM(
        k.status = 'abandoned'
    ) AS kyc_abandoned,

    ROUND(
        100.0 *
        SUM(k.status = 'completed')
        / COUNT(*),
        2
    ) AS kyc_completion_rate_pct

FROM kyc_applications k

JOIN users u
    ON k.user_id = u.user_id

GROUP BY
    u.device_type,
    u.signup_app_version

ORDER BY
    u.device_type,
    kyc_completion_rate_pct;


-- ============================================================
-- 3. KYC FAILURE REASONS BY APP VERSION
-- ============================================================

SELECT
    u.device_type,
    u.signup_app_version,
    k.failure_reason,

    COUNT(*) AS failures

FROM kyc_applications k

JOIN users u
    ON k.user_id = u.user_id

WHERE
    k.status = 'failed'

GROUP BY
    u.device_type,
    u.signup_app_version,
    k.failure_reason

ORDER BY failures DESC;


-- ============================================================
-- 4. WEEKLY KYC COMPLETION TREND
-- ============================================================

SELECT

    DATE(
        k.started_at
        - INTERVAL WEEKDAY(k.started_at) DAY
    ) AS week_start,

    COUNT(*) AS kyc_started,

    SUM(
        k.status = 'completed'
    ) AS kyc_completed,

    ROUND(
        100.0 *
        SUM(k.status = 'completed')
        / COUNT(*),
        2
    ) AS kyc_completion_rate_pct

FROM kyc_applications k

GROUP BY
    DATE(
        k.started_at
        - INTERVAL WEEKDAY(k.started_at) DAY
    )

ORDER BY week_start;


-- ============================================================
-- 5. WEEKLY KYC TREND BY DEVICE
-- ============================================================

SELECT

    DATE(
        k.started_at
        - INTERVAL WEEKDAY(k.started_at) DAY
    ) AS week_start,

    u.device_type,

    COUNT(*) AS kyc_started,

    SUM(
        k.status = 'completed'
    ) AS kyc_completed,

    ROUND(
        100.0 *
        SUM(k.status = 'completed')
        / COUNT(*),
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
    u.device_type

ORDER BY
    week_start,
    u.device_type;


-- ============================================================
-- 6. ACTIVATION BY ACQUISITION CHANNEL
-- ============================================================

WITH activated_users AS (

    SELECT DISTINCT
        user_id

    FROM events

    WHERE
        event_name = 'first_successful_transaction'
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
        COUNT(DISTINCT a.user_id)
        /
        COUNT(DISTINCT u.user_id),
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
-- 7. ACTIVATION BY CAMPAIGN
-- ============================================================

WITH activated_users AS (

    SELECT DISTINCT
        user_id

    FROM events

    WHERE
        event_name = 'first_successful_transaction'
)

SELECT

    u.acquisition_channel,
    u.campaign_name,

    COUNT(
        DISTINCT u.user_id
    ) AS acquired_users,

    COUNT(
        DISTINCT a.user_id
    ) AS activated_users,

    ROUND(
        100.0 *
        COUNT(DISTINCT a.user_id)
        /
        COUNT(DISTINCT u.user_id),
        2
    ) AS activation_rate_pct

FROM users u

LEFT JOIN activated_users a
    ON u.user_id = a.user_id

GROUP BY
    u.acquisition_channel,
    u.campaign_name

ORDER BY
    activation_rate_pct ASC;


-- ============================================================
-- 8. MOST IMPORTANT INVESTIGATION:
-- ANDROID KYC PERFORMANCE BY APP VERSION
-- ============================================================

SELECT

    u.signup_app_version,

    COUNT(*) AS kyc_started,

    SUM(
        k.status = 'completed'
    ) AS completed,

    SUM(
        k.status = 'failed'
    ) AS failed,

    SUM(
        k.status = 'abandoned'
    ) AS abandoned,

    ROUND(
        100.0 *
        SUM(k.status = 'completed')
        /
        COUNT(*),
        2
    ) AS completion_rate_pct

FROM kyc_applications k

JOIN users u
    ON k.user_id = u.user_id

WHERE
    u.device_type = 'Android'

GROUP BY
    u.signup_app_version

ORDER BY
    u.signup_app_version;


-- ============================================================
-- 9. ANDROID FAILURE REASON DEEP DIVE
-- ============================================================

SELECT

    u.signup_app_version,

    k.failure_reason,

    COUNT(*) AS failure_count,

    ROUND(
        100.0 *
        COUNT(*)
        /
        SUM(COUNT(*)) OVER (
            PARTITION BY u.signup_app_version
        ),
        2
    ) AS share_of_version_failures_pct

FROM kyc_applications k

JOIN users u
    ON k.user_id = u.user_id

WHERE
    u.device_type = 'Android'

    AND k.status = 'failed'

GROUP BY
    u.signup_app_version,
    k.failure_reason

ORDER BY
    u.signup_app_version,
    failure_count DESC;