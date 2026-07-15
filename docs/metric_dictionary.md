# PulsePay Metric Dictionary

## North Star Metric

### Weekly Successful Transacting Users (WSTU)
**Definition:** Number of unique users who complete at least one successful transaction during an ISO calendar week.

**Why it matters:** It captures recurring delivery of the product's core value: successfully moving or spending money.

---

## Activation Rate
**Initial definition:** Percentage of registered users who complete their first successful transaction within 7 days of signup.

**Formula:**
Activated users within 7 days / Registered users × 100

---

## KYC Completion Rate
**Definition:** Percentage of users who start KYC and successfully complete it.

**Formula:**
Completed KYC applications / Started KYC applications × 100

---

## Transaction Success Rate
**Definition:** Percentage of attempted transactions with status `success`.

**Formula:**
Successful transactions / All transaction attempts × 100

---

## D7 Retention
**Definition:** Percentage of users active on day 7 after signup, using the project's final agreed activity definition.

**Important:** The activity definition must be explicit before analysis.

---

## Guardrail Metric
A metric monitored to ensure that improving a primary experiment metric does not create unacceptable negative side effects.

Example:
- Primary metric: KYC Completion Rate
- Guardrail: Support Contact Rate
