USE pulsepay_analytics;

-- IMPORTANT:
-- Use MySQL Workbench's Table Data Import Wizard for each CSV.
-- Import into the EXISTING matching table.
--
-- Import order:
-- 1. users.csv
-- 2. kyc_applications.csv
-- 3. events.csv
-- 4. transactions.csv
-- 5. experiment_assignments.csv
-- 6. support_tickets.csv
--
-- After importing, run these checks:

SELECT 'users' AS table_name, COUNT(*) AS row_count FROM users
UNION ALL
SELECT 'events', COUNT(*) FROM events
UNION ALL
SELECT 'kyc_applications', COUNT(*) FROM kyc_applications
UNION ALL
SELECT 'transactions', COUNT(*) FROM transactions
UNION ALL
SELECT 'experiment_assignments', COUNT(*) FROM experiment_assignments
UNION ALL
SELECT 'support_tickets', COUNT(*) FROM support_tickets;

-- Confirm the hidden real-world incident exists in the data.
-- Do not put the answer in the final portfolio README yet:
-- the analysis phase should "discover" it.
SELECT
    device_type,
    app_version,
    COUNT(*) AS kyc_started,
    SUM(status = 'completed') AS kyc_completed,
    ROUND(100.0 * SUM(status = 'completed') / COUNT(*), 2) AS completion_rate_pct
FROM kyc_applications k
JOIN users u ON u.user_id = k.user_id
GROUP BY device_type, app_version
ORDER BY completion_rate_pct;
