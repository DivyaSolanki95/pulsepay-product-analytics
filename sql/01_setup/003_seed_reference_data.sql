USE pulsepay_analytics;

INSERT INTO experiments (
    experiment_name,
    hypothesis,
    primary_metric,
    guardrail_metric,
    start_date,
    end_date,
    status
)
VALUES (
    'KYC Flow Simplification',
    'Reducing the KYC flow from five steps to three will increase KYC completion without materially increasing support contacts.',
    'KYC Completion Rate',
    'Support Contact Rate',
    '2026-04-01',
    '2026-04-21',
    'completed'
);

SELECT * FROM experiments;
