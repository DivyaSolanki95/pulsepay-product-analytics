# PulsePay Data Dictionary

## Overview

PulsePay uses a synthetic relational dataset representing a fictional digital payments product.

The dataset models the user lifecycle across:

**Acquisition → Signup → KYC → Product Events → Transactions → Support → Experimentation**

> All data is synthetic and contains no real customer or personally identifiable information.

---

# 1. Users

**Table:** `users`

**Grain:** One row per user.

**Purpose:** Stores user-level acquisition, signup, device, and app-version attributes.

| Column | Description |
|---|---|
| `user_id` | Unique identifier for each user |
| `signup_timestamp` | Date and time the user created an account |
| `acquisition_channel` | Channel through which the user was acquired |
| `device_type` | User device/platform category |
| `signup_app_version` | App version associated with signup |

### Analytical Uses

- User acquisition analysis
- Signup cohort creation
- Device segmentation
- App-version segmentation
- User lifecycle analysis

---

# 2. Events

**Table:** `events`

**Grain:** One row per tracked product event.

**Purpose:** Stores behavioral events generated as users progress through the product.

Important events include:

- `otp_verified`
- `kyc_started`
- `kyc_completed`
- `bank_linked`
- `first_successful_transaction`

### Analytical Uses

- Funnel analysis
- Activation measurement
- User journey analysis
- Event-based behavioral analysis

---

# 3. KYC Applications

**Table:** `kyc_applications`

**Grain:** One row per KYC application or attempt.

**Purpose:** Tracks identity-verification attempts and outcomes.

Important analytical attributes include:

| Attribute | Description |
|---|---|
| `user_id` | User associated with the KYC attempt |
| `started_at` | Timestamp when KYC began |
| `status` | Final KYC outcome |
| `failure_reason` | Recorded reason for KYC failure |

Example KYC statuses:

- `completed`
- `failed`
- `abandoned`

An important failure reason used in the incident investigation is:

```text
document_upload_error
```

### Analytical Uses

- KYC conversion analysis
- Failure analysis
- Root-cause investigation
- App-version performance analysis
- Incident impact estimation

---

# 4. Transactions

**Table:** `transactions`

**Grain:** One row per transaction attempt.

**Purpose:** Stores payment transaction activity.

Important analytical attributes include:

| Attribute | Description |
|---|---|
| `transaction_id` | Unique transaction identifier |
| `user_id` | User performing the transaction |
| `transaction_timestamp` | Transaction date and time |
| `amount` | Transaction value |
| `status` | Transaction outcome |

Successful transactions are used to measure meaningful product usage.

### Analytical Uses

- Transaction success analysis
- Transaction value
- Product usage
- Weekly North Star metric
- Activation behavior
- Retention analysis

---

# 5. Support Tickets

**Table:** `support_tickets`

**Grain:** One row per customer-support ticket.

**Purpose:** Represents customer-support contacts.

### Analytical Uses

- Customer friction analysis
- Experiment guardrail measurement
- Product-quality monitoring

In the KYC experiment, support contact rate is used as a guardrail metric.

---

# 6. Experiment Assignments

**Table:** `experiment_assignments`

**Grain:** One row per user assigned to an experiment.

**Purpose:** Stores experiment assignment information.

Important attributes include:

| Attribute | Description |
|---|---|
| `user_id` | Experiment participant |
| `experiment_id` | Experiment identifier |
| `variant` | Assigned experiment group |

Variants used in the KYC experiment:

```text
control
treatment
```

### Analytical Uses

- Experiment allocation validation
- Control vs treatment comparison
- Sample-ratio-mismatch checks
- Statistical analysis

---

# Analytical Views

The project uses reusable MySQL views as a semantic layer between the raw relational tables and Power BI.

---

## `vw_executive_kpis`

Provides overall product-health metrics.

Includes:

- Total users
- Total transactions
- Successful transactions
- Transaction success rate
- Successful transacting users
- Successful transactor rate
- Successful transaction value

---

## `vw_weekly_north_star`

Provides weekly product-usage metrics.

Primary metric:

```text
Weekly Successful Transacting Users
```

A user is counted when they complete at least one successful transaction during a calendar week.

---

## `vw_onboarding_funnel`

Provides ordered onboarding-funnel stages:

```text
Account Created
→ OTP Verified
→ KYC Started
→ KYC Completed
→ Bank Linked
→ First Successful Transaction
```

---

## `vw_kyc_device_version`

Provides KYC performance segmented by:

- Device type
- App version

Metrics include:

- KYC attempts
- Completed applications
- Failed applications
- Abandoned applications
- Document-upload errors
- Completion rate
- Document-upload-error rate

---

## `vw_weekly_kyc_trend`

Provides weekly KYC performance segmented by:

- Week
- Device type
- App version

Used for incident trend analysis.

---

## `vw_acquisition_quality`

Compares acquisition channels using:

- Acquired users
- KYC completion
- Activation
- D30 retention
- Acquisition-quality score

The quality score is defined as:

```text
40% Activation
+
40% D30 Retention
+
20% KYC Completion
```

The score is a project-specific prioritization framework rather than a universal business metric.

---

## `vw_activation_retention`

Segments users by the number of successful transactions completed during the first seven days.

Groups:

```text
0 transactions
1 transaction
2 transactions
3–4 transactions
5+ transactions
```

Measures D30 retention for each behavioral group.

---

## `vw_cohort_retention`

Provides monthly cohort retention from:

```text
M0
through
M5
```

The cohort is defined by signup month.

Retention activity is based on successful transaction behavior.

---

## `vw_experiment_scorecard`

Provides experiment results by variant.

Metrics include:

- Assigned users
- KYC completion rate
- Support contact rate
- Activation rate

---

## `vw_kyc_incident_impact`

Provides a counterfactual estimate of the Android 5.4 KYC incident.

Includes:

- Affected KYC attempts
- Actual completions
- Document-upload errors
- Actual completion rate
- Reference completion rate
- Completion-rate gap
- Expected completions at reference performance
- Estimated additional KYC completions
- Post-KYC activation rate
- Estimated additional activated users

The estimate uses Android 5.3 as a reference baseline.

It should not be interpreted as proven causal impact.

---

# Metric Definitions

## Transaction Success Rate

```text
Successful Transactions
÷
All Transaction Attempts
```

---

## Successful Transacting User

A user who completed at least one successful transaction.

---

## Weekly Successful Transacting Users

Distinct users completing at least one successful transaction during a calendar week.

---

## Technical Activation

A user reaches:

```text
First Successful Transaction
```

---

## Early Product Behavior

Number of successful transactions completed during the first seven days after signup.

---

## D30 Retention

A user is considered retained when successful transaction activity is observed during the project's defined D30 measurement window.

See `docs/methodology.md` for the exact implementation and interpretation.

---

## KYC Completion Rate

```text
Completed KYC Applications
÷
KYC Attempts
```

---

## Support Contact Rate

```text
Experiment Users Contacting Support
÷
Assigned Experiment Users
```

---

# Data Disclosure

The complete dataset is synthetic.

PulsePay is a fictional product.

No real:

- Customers
- Financial transactions
- KYC records
- Support interactions
- Personally identifiable information

are included in this repository.