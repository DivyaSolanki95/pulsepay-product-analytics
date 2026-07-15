USE pulsepay_analytics;

-- ============================================================
-- PULSEPAY PRODUCT ANALYTICS
-- ANALYSIS 03: ROOT-CAUSE & BUSINESS IMPACT ANALYSIS
-- ============================================================
--
-- Investigation:
-- Did Android app version 5.4 create a KYC problem?
--
-- Product question:
-- 1. When did the problem begin?
-- 2. Which users were affected?
-- 3. What was the failure mechanism?
-- 4. How many KYC completions were potentially lost?
-- 5. How did this affect activation?
--
-- ============================================================


-- ============================================================
-- 1. ANDROID KYC PERFORMANCE BY VERSION
-- Establish the performance difference.
-- ============================================================

SELECT
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
-- 2. ANDROID 5.4 WEEKLY KYC TREND
-- Determine when performance changed.
-- ============================================================

SELECT

    DATE(
        k.started_at
        - INTERVAL WEEKDAY(k.started_at) DAY
    ) AS week_start,

    COUNT(*) AS kyc_started,

    SUM(
        k.status = 'completed'
    ) AS completed,

    SUM(
        k.status = 'failed'
    ) AS failed,

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

    AND u.signup_app_version = '5.4'

GROUP BY
    DATE(
        k.started_at
        - INTERVAL WEEKDAY(k.started_at) DAY
    )

ORDER BY week_start;


-- ============================================================
-- 3. FAILURE REASON COMPARISON
-- Identify the mechanism behind the problem.
-- ============================================================

SELECT

    u.signup_app_version,

    COALESCE(
        NULLIF(k.failure_reason, ''),
        'unknown'
    ) AS failure_reason,

    COUNT(*) AS failure_count,

    ROUND(
        100.0 *
        COUNT(*)
        /
        SUM(COUNT(*)) OVER (
            PARTITION BY u.signup_app_version
        ),
        2
    ) AS share_of_failures_pct

FROM kyc_applications k

JOIN users u
    ON k.user_id = u.user_id

WHERE
    u.device_type = 'Android'

    AND k.status = 'failed'

GROUP BY
    u.signup_app_version,
    COALESCE(
        NULLIF(k.failure_reason, ''),
        'unknown'
    )

ORDER BY
    u.signup_app_version,
    failure_count DESC;


-- ============================================================
-- 4. DOCUMENT UPLOAD ERROR RATE
-- Quantify the suspected technical failure.
-- ============================================================

SELECT

    u.signup_app_version,

    COUNT(*) AS total_kyc_attempts,

    SUM(
        k.failure_reason = 'document_upload_error'
    ) AS document_upload_errors,

    ROUND(
        100.0 *
        SUM(
            k.failure_reason = 'document_upload_error'
        )
        /
        COUNT(*),
        2
    ) AS document_upload_error_rate_pct

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
-- 5. ESTIMATE LOST KYC COMPLETIONS
-- Counterfactual:
-- What if Android 5.4 performed like Android 5.3?
-- ============================================================

WITH version_metrics AS (

    SELECT

        u.signup_app_version,

        COUNT(*) AS kyc_started,

        SUM(
            k.status = 'completed'
        ) AS completed,

        1.0 *
        SUM(
            k.status = 'completed'
        )
        /
        COUNT(*) AS completion_rate

    FROM kyc_applications k

    JOIN users u
        ON k.user_id = u.user_id

    WHERE
        u.device_type = 'Android'

        AND u.signup_app_version IN (
            '5.3',
            '5.4'
        )

    GROUP BY
        u.signup_app_version
),

baseline AS (

    SELECT
        completion_rate AS baseline_completion_rate

    FROM version_metrics

    WHERE
        signup_app_version = '5.3'
),

affected AS (

    SELECT
        kyc_started,
        completed,
        completion_rate

    FROM version_metrics

    WHERE
        signup_app_version = '5.4'
)

SELECT

    a.kyc_started AS android_54_kyc_attempts,

    a.completed AS actual_completions,

    ROUND(
        b.baseline_completion_rate * 100,
        2
    ) AS expected_completion_rate_pct,

    ROUND(
        a.completion_rate * 100,
        2
    ) AS actual_completion_rate_pct,

    ROUND(
        a.kyc_started *
        b.baseline_completion_rate
    ) AS expected_completions_at_baseline,

    ROUND(

        (
            a.kyc_started *
            b.baseline_completion_rate
        )

        - a.completed

    ) AS estimated_lost_kyc_completions

FROM affected a

CROSS JOIN baseline b;


-- ============================================================
-- 6. POST-KYC ACTIVATION RATE
-- Of users who complete KYC, how many eventually activate?
-- ============================================================

WITH completed_kyc_users AS (

    SELECT DISTINCT
        user_id

    FROM kyc_applications

    WHERE
        status = 'completed'
),

activated_users AS (

    SELECT DISTINCT
        user_id

    FROM events

    WHERE
        event_name =
        'first_successful_transaction'
)

SELECT

    COUNT(
        DISTINCT k.user_id
    ) AS completed_kyc_users,

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
            DISTINCT k.user_id
        ),
        2
    ) AS post_kyc_activation_rate_pct

FROM completed_kyc_users k

LEFT JOIN activated_users a
    ON k.user_id = a.user_id;


-- ============================================================
-- 7. ESTIMATE LOST ACTIVATED USERS
-- Lost KYC completions × post-KYC activation probability
-- ============================================================

WITH version_metrics AS (

    SELECT

        u.signup_app_version,

        COUNT(*) AS kyc_started,

        SUM(
            k.status = 'completed'
        ) AS completed,

        1.0 *
        SUM(
            k.status = 'completed'
        )
        /
        COUNT(*) AS completion_rate

    FROM kyc_applications k

    JOIN users u
        ON k.user_id = u.user_id

    WHERE
        u.device_type = 'Android'

        AND u.signup_app_version IN (
            '5.3',
            '5.4'
        )

    GROUP BY
        u.signup_app_version
),

impact AS (

    SELECT

        MAX(
            CASE
                WHEN signup_app_version = '5.3'
                THEN completion_rate
            END
        ) AS baseline_rate,

        MAX(
            CASE
                WHEN signup_app_version = '5.4'
                THEN kyc_started
            END
        ) AS affected_attempts,

        MAX(
            CASE
                WHEN signup_app_version = '5.4'
                THEN completed
            END
        ) AS actual_completions

    FROM version_metrics
),

post_kyc AS (

    SELECT

        1.0 *
        COUNT(
            DISTINCT CASE
                WHEN e.event_name =
                'first_successful_transaction'
                THEN k.user_id
            END
        )
        /
        COUNT(
            DISTINCT k.user_id
        ) AS activation_rate

    FROM kyc_applications k

    LEFT JOIN events e
        ON k.user_id = e.user_id

    WHERE
        k.status = 'completed'
)

SELECT

    ROUND(

        (
            i.affected_attempts *
            i.baseline_rate
        )

        - i.actual_completions

    ) AS estimated_lost_kyc_completions,

    ROUND(
        p.activation_rate * 100,
        2
    ) AS post_kyc_activation_rate_pct,

    ROUND(

        (

            (
                i.affected_attempts *
                i.baseline_rate
            )

            - i.actual_completions

        )

        * p.activation_rate

    ) AS estimated_lost_activated_users

FROM impact i

CROSS JOIN post_kyc p;


-- ============================================================
-- 8. SUPPORT TICKET VALIDATION
-- Does customer feedback support the quantitative finding?
-- ============================================================

SELECT

    u.signup_app_version,

    s.category,

    COUNT(*) AS support_tickets

FROM support_tickets s

JOIN users u
    ON s.user_id = u.user_id

WHERE
    u.device_type = 'Android'

GROUP BY
    u.signup_app_version,
    s.category

ORDER BY
    u.signup_app_version,
    support_tickets DESC;


-- ============================================================
-- 9. KYC ISSUE RATE IN SUPPORT TICKETS
-- ============================================================

SELECT

    u.signup_app_version,

    COUNT(*) AS total_support_tickets,

    SUM(
        s.category = 'KYC Issues'
    ) AS kyc_issue_tickets,

    ROUND(
        100.0 *
        SUM(
            s.category = 'KYC Issues'
        )
        /
        COUNT(*),
        2
    ) AS kyc_issue_share_pct

FROM support_tickets s

JOIN users u
    ON s.user_id = u.user_id

WHERE
    u.device_type = 'Android'

GROUP BY
    u.signup_app_version

ORDER BY
    u.signup_app_version;


-- ============================================================
-- 10. ROOT-CAUSE SUMMARY DATASET
-- Final evidence table for dashboard/case study.
-- ============================================================

SELECT

    u.device_type,

    u.signup_app_version,

    COUNT(*) AS kyc_attempts,

    SUM(
        k.status = 'completed'
    ) AS completed,

    SUM(
        k.status = 'failed'
    ) AS failed,

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
    u.signup_app_version

ORDER BY
    completion_rate_pct ASC;