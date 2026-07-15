USE pulsepay_analytics;

-- Confirm all expected tables exist.
SHOW TABLES;

-- Confirm table structures.
DESCRIBE users;
DESCRIBE events;
DESCRIBE kyc_applications;
DESCRIBE transactions;
DESCRIBE experiments;
DESCRIBE experiment_assignments;
DESCRIBE support_tickets;
DESCRIBE daily_product_metrics;

-- Row counts will be zero until synthetic data is loaded.
SELECT 'users' AS table_name, COUNT(*) AS row_count FROM users
UNION ALL
SELECT 'events', COUNT(*) FROM events
UNION ALL
SELECT 'kyc_applications', COUNT(*) FROM kyc_applications
UNION ALL
SELECT 'transactions', COUNT(*) FROM transactions
UNION ALL
SELECT 'experiments', COUNT(*) FROM experiments
UNION ALL
SELECT 'experiment_assignments', COUNT(*) FROM experiment_assignments
UNION ALL
SELECT 'support_tickets', COUNT(*) FROM support_tickets;
