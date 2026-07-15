# PulsePay — Product Growth & Experimentation Intelligence Platform

A portfolio-grade Product Analytics project that simulates a real fintech product and answers real product questions using SQL, Python, experimentation, retention analysis, and product decision-making.

## Business problem
PulsePay is a fictional digital payments product. The product team needs to understand:
- Where users drop off during onboarding
- What behaviors predict activation and retention
- Why core product metrics change
- Which acquisition channels bring high-quality users
- Whether product experiments create statistically meaningful impact
- Which product opportunities should be prioritized

## North Star Metric
**Weekly Successful Transacting Users (WSTU)**

A user counts toward WSTU if they complete at least one successful transaction during a calendar week.

## Product journey
Install → Sign Up → OTP Verified → KYC Started → KYC Completed → Bank Linked → First Successful Transaction → Repeat Transaction → Retained User

## Tech stack
- MySQL 8 / MySQL Workbench
- Python
- Pandas / NumPy / SciPy / scikit-learn
- Power BI or a web dashboard in a later phase
- Git + GitHub
- Docker / AWS in the deployment phase

## Repository structure
- `sql/01_setup/` — database schema and setup
- `sql/02_analysis/` — product analysis queries
- `sql/03_experiments/` — A/B testing analysis
- `data/` — generated datasets
- `python/data_generation/` — realistic synthetic event generation
- `python/analysis/` — deeper statistical/product analysis
- `dashboard/` — dashboard work
- `docs/` — product documentation, metric dictionary, case study
- `assets/` — screenshots and diagrams

## Phase 1
1. Create the MySQL database.
2. Run `sql/01_setup/001_create_database.sql`.
3. Run `sql/01_setup/002_create_tables.sql`.
4. Run `sql/01_setup/003_seed_reference_data.sql`.
5. Validate using `sql/01_setup/004_quality_checks.sql`.

## Portfolio goal
This project is designed as an end-to-end Product Analyst case study, not merely a dashboard. Every major analysis follows:

**Observation → Diagnosis → Impact → Recommendation → Measurement**
