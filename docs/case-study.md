# PulsePay Product Analytics Case Study

## From Product Health to Product Decision

**Author:** Divya Solanki  
**Role:** Product Analyst  
**Tools:** MySQL · SQL · Python · Pandas · Statistical Testing · Power BI

---

## Executive Summary

PulsePay is a fictional digital payments product created as an end-to-end product analytics case study.

The analysis examined the user lifecycle across:

**Acquisition → Signup → KYC → Activation → Transaction → Retention**

The investigation focused on three major product questions:

1. Where does friction exist in the onboarding and activation journey?
2. What explains a significant deterioration in KYC completion for a specific user segment?
3. Did a proposed KYC experience improve conversion enough to justify rollout?

The most significant finding was a substantial KYC performance gap for **Android app version 5.4**.

The affected segment recorded:

- **5,150 KYC attempts**
- **54.56% KYC completion**
- **1,476 document-upload errors**

Android 5.3 was used as a reference baseline and recorded a **75.60% KYC completion rate**.

This represented a:

> **21.04 percentage-point completion-rate gap**

Using the reference version as a counterfactual baseline, the analysis estimated:

- **1,084 additional KYC completions** at baseline performance
- Approximately **624 additional downstream activated users**

These figures are estimates rather than proven causal impact.

A separate KYC experiment showed a directional improvement in completion from **60.67% to 62.22%**, but the result was **not statistically significant** (`p = 0.217`).

The experiment also triggered a **sample-ratio-mismatch warning** (`p = 0.0268`).

The resulting product decision was therefore:

> **Do not declare the treatment a winner. Investigate experiment assignment integrity and continue testing before rollout.**

---

# 1. Product Context

Digital payment products depend on users successfully progressing through several critical stages:

```text
Acquisition
    ↓
Account Creation
    ↓
Identity Verification
    ↓
Bank Linking
    ↓
First Successful Transaction
    ↓
Repeated Product Usage
    ↓
Retention
```

A failure at an early stage can reduce the number of users available to activate and eventually become retained customers.

For PulsePay, the analytical objective was therefore not simply to report metrics.

The objective was to understand:

> **Where is product value being lost, why is it happening, and what should the product team do next?**

---

# 2. Analytical Approach

The project followed a layered analytical framework.

## Layer 1 — Product Health

Establish the overall state of the product using:

- User volume
- Successful transactions
- Transaction success rate
- Successful transacting users
- Transaction value
- Weekly meaningful usage

## Layer 2 — Funnel Analysis

Measure progression through:

```text
Account Created
→ OTP Verified
→ KYC Started
→ KYC Completed
→ Bank Linked
→ First Successful Transaction
```

## Layer 3 — Root-Cause Investigation

Segment product performance by:

- Device type
- App version
- KYC outcome
- Failure reason
- Time

## Layer 4 — Retention Analysis

Evaluate:

- D30 retention
- Early transaction behavior
- Behavioral activation
- Monthly cohorts

## Layer 5 — Acquisition Quality

Compare acquisition sources using downstream outcomes rather than sign-up volume alone.

## Layer 6 — Experimentation

Evaluate a proposed product change using:

- Primary metric
- Guardrail metric
- Downstream metric
- Statistical significance
- Confidence intervals
- Sample-ratio-mismatch checks

---

# 3. Defining Meaningful Product Usage

A central analytical decision was distinguishing between **registration** and **meaningful product usage**.

A user creating an account does not necessarily mean that the product has delivered value.

For a payments product, a stronger behavioral signal is:

> **Completing a successful transaction**

The project's North Star metric was therefore defined as:

## Weekly Successful Transacting Users

A user is counted if they complete at least one successful transaction during a calendar week.

This metric was chosen because it represents actual product usage rather than passive account ownership.

---

# 4. Activation Analysis

The project uses two concepts of activation.

## Technical Activation

A user completes their first successful transaction.

## Behavioral Activation

A user establishes repeated meaningful product usage during the early lifecycle.

The analysis examined the number of successful transactions completed within the first seven days and compared this behavior with D30 retention.

Users were grouped into:

```text
0 transactions
1 transaction
2 transactions
3–4 transactions
5+ transactions
```

This analysis was designed to answer:

> **Does stronger early product engagement identify users who are more likely to remain active later?**

The relationship is observational.

A positive association between early usage and retention does not prove that forcing additional transactions would cause retention to increase.

However, the analysis can identify a useful behavioral signal for:

- Activation measurement
- Lifecycle messaging
- Product education
- Onboarding experiments
- Retention strategy

---

# 5. The KYC Incident

## Problem

KYC is a critical stage in the PulsePay onboarding journey.

Users who cannot complete identity verification cannot progress normally toward downstream product usage.

The analysis therefore segmented KYC performance across:

- Device type
- App version
- Failure reason
- Time

A major performance gap was isolated to:

> **Android app version 5.4**

---

## Evidence

The affected segment recorded:

| Metric | Android 5.4 |
|---|---:|
| KYC attempts | 5,150 |
| Completed KYC | 2,810 |
| Document-upload errors | 1,476 |
| KYC completion rate | 54.56% |

Android 5.3 was selected as the reference version.

Its KYC completion rate was:

> **75.60%**

Therefore:

```text
75.60% reference completion
−
54.56% affected completion
=
21.04 percentage-point gap
```

The affected segment also showed elevated document-upload errors.

This provided a plausible failure mechanism:

```text
Android 5.4
    ↓
Elevated document-upload errors
    ↓
Lower KYC completion
    ↓
Fewer users available for downstream activation
```

---

# 6. Estimating Business Impact

To translate the conversion problem into potential business impact, Android 5.3 was used as a counterfactual reference baseline.

The calculation asked:

> **How many Android 5.4 users might have completed KYC if the segment had performed at the Android 5.3 completion rate?**

## Expected completions at baseline performance

```text
5,150 KYC attempts
×
75.60% reference completion rate
≈
3,894 expected KYC completions
```

Actual completions:

```text
2,810
```

Estimated difference:

```text
3,894
−
2,810
=
1,084 estimated additional KYC completions
```

The observed post-KYC activation rate was:

```text
57.62%
```

Applying this rate to the estimated completion difference produced:

```text
1,084
×
57.62%
≈
624 estimated additional activated users
```

---

## Interpretation

The analysis therefore estimated:

> **Approximately 1,084 additional users may have completed KYC and approximately 624 additional users may have reached downstream activation if Android 5.4 had performed at the Android 5.3 reference rate.**

This is a counterfactual estimate.

It does not prove that the app version alone caused exactly 1,084 lost KYC completions or 624 lost activated users.

Other differences between the segments could contribute to the observed performance gap.

---

# 7. Product Recommendation for the Incident

The recommended response is:

## Immediate

1. Investigate the Android 5.4 document-upload flow.
2. Compare the affected implementation with Android 5.3.
3. Review technical logs for upload failures.
4. Validate device-, OS-, and network-specific failure patterns.

## Recovery

5. Release the fix through a controlled rollout.
6. Monitor KYC completion and document-upload errors.
7. Compare post-fix performance with the reference version.

## Prevention

8. Add automated monitoring by app version.
9. Alert on statistically or operationally meaningful KYC deterioration.
10. Include conversion guardrails in future mobile releases.

The broader product lesson is:

> **Aggregate metrics can hide severe segment-level product failures.**

---

# 8. Acquisition Quality

Acquisition channels were evaluated across:

- Acquired users
- KYC completion
- Activation
- D30 retention

This was designed to challenge a common growth assumption:

> **The channel bringing the most users is not necessarily bringing the most valuable users.**

A relative acquisition-quality score was created using:

```text
40% Activation Rate
+
40% D30 Retention
+
20% KYC Completion
```

The weighting reflects a product-prioritization choice.

It is not intended as a universal formula.

The purpose of the score is to provide a simple framework for comparing channels using downstream product quality.

---

## Product Recommendation

Acquisition decisions should consider:

```text
Acquisition Volume
        +
Activation Quality
        +
Retention Quality
```

rather than:

```text
Sign-ups alone
```

A high-volume channel with weak downstream behavior may be less valuable than a smaller channel producing highly activated and retained users.

---

# 9. Cohort Retention

Monthly signup cohorts were analyzed based on successful transaction activity.

The cohort framework tracks:

```text
M0 = Signup month
M1 = One month after signup
M2 = Two months after signup
...
M5 = Five months after signup
```

This provides a lifecycle view that aggregate retention metrics cannot provide.

Cohort analysis helps answer:

- Are newer users retaining better?
- Is product quality improving over time?
- Are acquisition changes affecting user quality?
- Did a product incident affect specific cohorts?

Recent cohorts naturally contain incomplete later-month observations.

These cells should be interpreted as not-yet-observed rather than zero retention.

---

# 10. The KYC Experiment

A separate experiment evaluated a proposed KYC experience.

## Hypothesis

> Simplifying the KYC experience will improve KYC completion without increasing support contacts.

## Primary Metric

**KYC Completion Rate**

## Guardrail Metric

**Support Contact Rate**

## Downstream Metric

**Activation Rate**

---

# 11. Experiment Validation

Before comparing outcomes, the experiment data was validated.

The experiment contained:

```text
6,032 users
```

Assignment:

| Variant | Users |
|---|---:|
| Control | 3,102 |
| Treatment | 2,930 |

Duplicate experiment users:

```text
0
```

However, the 50/50 allocation check produced:

```text
Chi-square = 4.9045
P-value = 0.0268
```

This triggered a:

> **Sample Ratio Mismatch warning**

This should be investigated before making a rollout decision.

Potential causes could include:

- Assignment logic
- Eligibility filtering
- Instrumentation problems
- Missing assignment records
- Post-assignment data loss
- Random variation

The analysis does not assume which explanation is correct.

---

# 12. Experiment Results

## Primary Metric

| Variant | KYC Completion |
|---|---:|
| Control | 60.67% |
| Treatment | 62.22% |

Observed lift:

```text
Absolute lift:
+1.55 percentage points

Relative lift:
+2.55%
```

At first glance, the treatment appears better.

However, metric movement alone is not sufficient evidence for a product decision.

---

## Statistical Test

A two-proportion z-test was used.

Results:

```text
Z-score:
1.2343

P-value:
0.2171

95% confidence interval:
[-0.91, +4.00] percentage points
```

Because:

```text
p-value > 0.05
```

the result was not statistically significant at the conventional 5% significance level.

The confidence interval also includes zero.

Therefore, the observed data is compatible with:

- A small negative treatment effect
- No effect
- A positive treatment effect

The experiment does not provide sufficient evidence to establish a winner.

---

# 13. Guardrail and Downstream Metrics

| Metric | Control | Treatment |
|---|---:|---:|
| Support contact rate | 13.70% | 13.41% |
| Activation rate | 39.36% | 39.59% |

Both metrics moved slightly in a favorable direction for treatment.

However, these differences should be treated as directional unless separately tested and included in a predefined experiment analysis plan.

---

# 14. Experiment Decision

## Decision

> **DO NOT CLAIM A WINNER**

The treatment's KYC completion rate was higher, but the experiment did not provide sufficient statistical evidence that the treatment caused an improvement.

The sample-ratio-mismatch warning also creates an experiment-integrity concern.

## Recommended Next Steps

1. Investigate the assignment imbalance.
2. Verify experiment instrumentation.
3. Define a minimum detectable effect.
4. Perform an experiment power calculation.
5. Predefine primary and guardrail decision criteria.
6. Continue or rerun the experiment if the setup is valid.
7. Do not ship solely because the treatment metric is numerically higher.

---

# 15. Dashboard Design

The Power BI report is organized around product decisions rather than isolated charts.

## Page 1 — Executive Overview

Answers:

> What is the current state of the product?

Includes:

- Executive KPIs
- North Star trend
- Onboarding funnel
- Acquisition quality

## Page 2 — Growth & Retention

Answers:

> What behaviors and acquisition sources are associated with durable usage?

Includes:

- Early behavior vs D30 retention
- Cohort retention
- Acquisition-channel quality

## Page 3 — KYC Incident

Answers:

> Where did KYC performance deteriorate, what is the likely mechanism, and what is the estimated impact?

Includes:

- Version-level KYC performance
- Document-upload errors
- Weekly trends
- Incident impact

## Page 4 — Experiment Lab

Answers:

> Should the proposed KYC experience be rolled out?

Includes:

- Experiment allocation
- Primary metric
- Guardrail metric
- Downstream activation
- Statistical evidence
- Product decision

---

# 16. Analytical Principles Demonstrated

This project intentionally applies several principles of responsible product analytics.

## Do not confuse correlation with causation

Early transaction behavior may predict retention without necessarily causing it.

## Do not confuse directional lift with statistical evidence

A treatment metric being higher does not automatically make the treatment a winner.

## Validate experiments before interpreting outcomes

Sample allocation and data integrity should be checked before making experiment decisions.

## Segment aggregate metrics

Aggregate product health can hide severe problems affecting specific platforms or versions.

## Translate metrics into decisions

The purpose of analysis is not simply to produce charts.

The final question is:

> **What should the product team do next?**

---

# 17. Limitations

## Synthetic Data

PulsePay is fictional, and the dataset is synthetically generated for portfolio purposes.

## Counterfactual Incident Estimate

The incident-impact estimate assumes Android 5.3 is a reasonable reference for Android 5.4.

## Observational Retention Analysis

The relationship between early product behavior and retention does not establish causality.

## Experiment Integrity

The sample-ratio-mismatch warning should be investigated before relying on the experiment for a rollout decision.

## Statistical Power

A non-significant result does not prove that the treatment has exactly zero effect.

The experiment may lack sufficient power to detect smaller effects.

---

# 18. Final Product Recommendations

Based on the complete analysis:

1. **Prioritize investigation of the Android 5.4 document-upload experience.**
2. **Implement version-level KYC monitoring and alerting.**
3. **Track meaningful product usage as a core activation signal.**
4. **Investigate interventions that help users establish early repeated usage.**
5. **Evaluate acquisition sources using downstream quality, not volume alone.**
6. **Investigate the experiment's sample-ratio mismatch.**
7. **Define power and minimum detectable effect before future experiments.**
8. **Avoid rollout decisions based solely on directional metric movement.**

---

# Conclusion

The PulsePay project demonstrates an end-to-end product analytics workflow:

```text
Measure product health
        ↓
Identify funnel friction
        ↓
Segment the problem
        ↓
Investigate root cause
        ↓
Estimate business impact
        ↓
Understand retention behavior
        ↓
Evaluate acquisition quality
        ↓
Test a proposed solution
        ↓
Quantify uncertainty
        ↓
Make a product recommendation
```

The central objective was not to create the largest possible dashboard.

It was to demonstrate how a Product Analyst can move from:

> **“What happened?”**

to:

> **“Why might it have happened?”**

and finally:

> **“What should the product team do next?”**