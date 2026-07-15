-- PulsePay Product Analytics
-- Phase 1: Database creation

DROP DATABASE IF EXISTS pulsepay_analytics;
CREATE DATABASE pulsepay_analytics
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE pulsepay_analytics;

SELECT DATABASE() AS active_database;
