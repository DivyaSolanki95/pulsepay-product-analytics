USE pulsepay_analytics;

-- =========================================================
-- 1. USERS
-- One row per registered user.
-- =========================================================
CREATE TABLE users (
    user_id BIGINT PRIMARY KEY,
    signup_timestamp DATETIME NOT NULL,
    acquisition_channel VARCHAR(50) NOT NULL,
    campaign_name VARCHAR(100),
    device_type ENUM('Android', 'iOS', 'Web') NOT NULL,
    city_tier ENUM('Tier 1', 'Tier 2', 'Tier 3') NOT NULL,
    age_group VARCHAR(20),
    signup_app_version VARCHAR(20),
    is_premium BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_users_signup (signup_timestamp),
    INDEX idx_users_channel (acquisition_channel),
    INDEX idx_users_device (device_type)
);

-- =========================================================
-- 2. EVENTS
-- Event-level behavioral data.
-- =========================================================
CREATE TABLE events (
    event_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    session_id VARCHAR(64) NOT NULL,
    event_name VARCHAR(80) NOT NULL,
    event_timestamp DATETIME NOT NULL,
    feature_name VARCHAR(80),
    app_version VARCHAR(20),
    device_type ENUM('Android', 'iOS', 'Web') NOT NULL,
    event_properties JSON,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    INDEX idx_events_user_time (user_id, event_timestamp),
    INDEX idx_events_name_time (event_name, event_timestamp),
    INDEX idx_events_version (app_version)
);

-- =========================================================
-- 3. KYC APPLICATIONS
-- Captures onboarding verification performance.
-- =========================================================
CREATE TABLE kyc_applications (
    kyc_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    started_at DATETIME NOT NULL,
    completed_at DATETIME,
    status ENUM('started', 'completed', 'failed', 'abandoned') NOT NULL,
    failure_reason VARCHAR(150),
    flow_version VARCHAR(30) NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    INDEX idx_kyc_status (status),
    INDEX idx_kyc_started (started_at)
);

-- =========================================================
-- 4. TRANSACTIONS
-- Core monetizable/product-value behavior.
-- =========================================================
CREATE TABLE transactions (
    transaction_id BIGINT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    transaction_timestamp DATETIME NOT NULL,
    transaction_type ENUM(
        'UPI',
        'Bill Payment',
        'Mobile Recharge',
        'Wallet Transfer',
        'Merchant Payment'
    ) NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    status ENUM('success', 'failed', 'pending') NOT NULL,
    failure_reason VARCHAR(150),
    payment_partner VARCHAR(80),
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    INDEX idx_txn_user_time (user_id, transaction_timestamp),
    INDEX idx_txn_status_time (status, transaction_timestamp)
);

-- =========================================================
-- 5. EXPERIMENTS
-- Experiment definitions.
-- =========================================================
CREATE TABLE experiments (
    experiment_id INT AUTO_INCREMENT PRIMARY KEY,
    experiment_name VARCHAR(120) NOT NULL UNIQUE,
    hypothesis TEXT NOT NULL,
    primary_metric VARCHAR(120) NOT NULL,
    guardrail_metric VARCHAR(120),
    start_date DATE NOT NULL,
    end_date DATE,
    status ENUM('planned', 'running', 'completed', 'stopped') NOT NULL
);

-- =========================================================
-- 6. EXPERIMENT ASSIGNMENTS
-- One row per user assignment.
-- =========================================================
CREATE TABLE experiment_assignments (
    assignment_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    experiment_id INT NOT NULL,
    user_id BIGINT NOT NULL,
    variant ENUM('control', 'treatment') NOT NULL,
    assigned_at DATETIME NOT NULL,
    FOREIGN KEY (experiment_id) REFERENCES experiments(experiment_id),
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    UNIQUE KEY uq_experiment_user (experiment_id, user_id),
    INDEX idx_assignment_variant (experiment_id, variant)
);

-- =========================================================
-- 7. SUPPORT TICKETS
-- Voice-of-customer data.
-- =========================================================
CREATE TABLE support_tickets (
    ticket_id BIGINT PRIMARY KEY,
    user_id BIGINT,
    created_at DATETIME NOT NULL,
    category VARCHAR(80) NOT NULL,
    issue_text TEXT NOT NULL,
    sentiment ENUM('positive', 'neutral', 'negative') NOT NULL,
    resolution_time_hours DECIMAL(8,2),
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    INDEX idx_ticket_category_time (category, created_at)
);

-- =========================================================
-- 8. DAILY PRODUCT METRICS
-- Optional aggregate table for dashboards and anomaly detection.
-- =========================================================
CREATE TABLE daily_product_metrics (
    metric_date DATE NOT NULL,
    metric_name VARCHAR(100) NOT NULL,
    metric_value DECIMAL(18,4) NOT NULL,
    segment_type VARCHAR(50) NOT NULL DEFAULT 'overall',
    segment_value VARCHAR(100) NOT NULL DEFAULT 'all',
    PRIMARY KEY (metric_date, metric_name, segment_type, segment_value)
);

SHOW TABLES;
