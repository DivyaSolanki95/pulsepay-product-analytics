USE pulsepay_analytics;

-- ============================================================
-- PULSEPAY PRODUCT ANALYTICS
-- KYC INCIDENT IMPACT VIEW
-- ============================================================
--
-- Purpose:
-- Quantify the estimated impact of the Android 5.4 KYC issue.
--
-- Method:
-- Compare Android 5.4 KYC completion with Android 5.3,
-- which is used as the baseline/reference version.
--
-- IMPORTANT:
-- This is a counterfactual estimate, not proven causal impact.
-- ============================================================


CREATE OR REPLACE VIEW vw_kyc_incident_impact AS

WITH version_metrics AS (

    SELECT

        u.signup_app_version AS app_version,

        COUNT(*) AS kyc_attempts,

        SUM(
            CASE
                WHEN k.status = 'completed'
                THEN 1
                ELSE 0
            END
        ) AS completed_kyc,

        SUM(
            CASE
                WHEN k.failure_reason = 'document_upload_error'
                THEN 1
                ELSE 0
            END
        ) AS document_upload_errors,

        1.0 *
        SUM(
            CASE
                WHEN k.status = 'completed'
                THEN 1
                ELSE 0
            END
        )
        /
        NULLIF(
            COUNT(*),
            0
        ) AS completion_rate

    FROM kyc_applications k

    JOIN users u
        ON k.user_id = u.user_id

    WHERE
        u.device_type = 'Android'

        AND u.signup_app_version
            IN ('5.3', '5.4')

    GROUP BY
        u.signup_app_version
),

baseline AS (

    SELECT

        completion_rate
            AS baseline_completion_rate

    FROM version_metrics

    WHERE
        app_version = '5.3'
),

affected AS (

    SELECT
        *

    FROM version_metrics

    WHERE
        app_version = '5.4'
),

activation_rate AS (

    SELECT

        1.0 *
        COUNT(
            DISTINCT CASE
                WHEN e.event_name =
                     'first_successful_transaction'
                THEN e.user_id
            END
        )
        /
        NULLIF(
            COUNT(
                DISTINCT CASE
                    WHEN k.status = 'completed'
                    THEN k.user_id
                END
            ),
            0
        ) AS post_kyc_activation_rate

    FROM kyc_applications k

    JOIN users u
        ON k.user_id = u.user_id

    LEFT JOIN events e
        ON k.user_id = e.user_id

    WHERE
        u.device_type = 'Android'

        AND u.signup_app_version = '5.4'
)

SELECT

    'Android 5.4' AS affected_segment,

    a.kyc_attempts,

    a.completed_kyc,

    a.document_upload_errors,

    ROUND(
        a.completion_rate * 100,
        2
    ) AS actual_completion_rate_pct,

    ROUND(
        b.baseline_completion_rate * 100,
        2
    ) AS baseline_completion_rate_pct,

    ROUND(
        (
            b.baseline_completion_rate
            -
            a.completion_rate
        ) * 100,
        2
    ) AS completion_rate_gap_pp,

    ROUND(
        a.kyc_attempts
        *
        b.baseline_completion_rate
    ) AS expected_completions_at_baseline,

    GREATEST(
        0,

        ROUND(
            (
                a.kyc_attempts
                *
                b.baseline_completion_rate
            )
            -
            a.completed_kyc
        )

    ) AS estimated_lost_kyc_completions,

    ROUND(
        ar.post_kyc_activation_rate
        * 100,
        2
    ) AS post_kyc_activation_rate_pct,

    GREATEST(
        0,

        ROUND(

            (
                (
                    a.kyc_attempts
                    *
                    b.baseline_completion_rate
                )
                -
                a.completed_kyc
            )

            *

            ar.post_kyc_activation_rate

        )

    ) AS estimated_lost_activated_users

FROM affected a

CROSS JOIN baseline b

CROSS JOIN activation_rate ar;