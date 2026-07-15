# PulsePay Analytical Methodology

## Purpose

This document explains the analytical definitions, assumptions, statistical methods, and limitations used in the PulsePay Product Analytics project.

The goal is to make the analysis:

- Transparent
- Reproducible
- Interpretable
- Explicit about uncertainty

---

# 1. Analytical Workflow

The project follows this workflow:

```text
Define the product question
        ↓
Validate the available data
        ↓
Define metrics
        ↓
Analyze aggregate product health
        ↓
Segment performance
        ↓
Investigate anomalies
        ↓
Estimate potential impact
        ↓
Evaluate user behavior
        ↓
Test product hypotheses
        ↓
Quantify uncertainty
        ↓
Make a product recommendation
```

---

# 2. Product Health

Product health is evaluated using:

- Total users
- Successful transacting users
- Transaction volume
- Transaction value
- Transaction success rate
- Weekly successful transacting users

These metrics provide context before deeper diagnostic analysis begins.

---

# 3. North Star Metric

## Weekly Successful Transacting Users

The project's North Star metric counts:

> Distinct users completing at least one successful transaction during a calendar week.

### Rationale

Account creation alone does not indicate that the user received meaningful value.

Successful transaction activity is a stronger indicator of actual usage for a digital payments product.

### Limitation

A single successful transaction does not necessarily indicate long-term product adoption.

The metric should therefore be interpreted alongside:

- Transaction frequency
- Retention
- Cohort behavior

---

# 4. Funnel Methodology

The onboarding journey is modeled as:

```text
Account Created
→ OTP Verified
→ KYC Started
→ KYC Completed
→ Bank Linked
→ First Successful Transaction
```

Distinct users reaching each stage are counted.

### Interpretation

The funnel is used to identify stages where substantial user loss occurs.

A funnel drop does not by itself explain why users fail to progress.

Segmented analysis is required for diagnosis.

---

# 5. Activation Methodology

The project distinguishes between two activation concepts.

## Technical Activation

A user completes their first successful transaction.

## Behavioral Activation

A user establishes repeated meaningful usage during the early lifecycle.

The project evaluates the number of successful transactions completed within the first seven days.

Users are grouped into:

```text
0 transactions
1 transaction
2 transactions
3–4 transactions
5+ transactions
```

D30 retention is then compared across these groups.

### Interpretation

If users with stronger early usage also show stronger later retention, early transaction behavior may be useful as:

- An activation signal
- A segmentation feature
- A lifecycle intervention target

### Causal Limitation

The relationship is observational.

Users who transact frequently may already differ in motivation, need, intent, or other characteristics.

Therefore:

> Association between early usage and retention does not prove that forcing additional early transactions will cause retention to increase.

---

# 6. D30 Retention Definition

For this project, a user is considered D30 retained when they complete a successful transaction during the defined day-30 observation window.

The implemented SQL uses:

```text
Day 30 through Day 37 after signup
```

This window reduces sensitivity to users returning slightly before or after an exact calendar day.

### Important Interpretation

This is a project-specific retention definition.

Other products may use:

- Exact Day 30 retention
- Rolling retention
- Unbounded retention
- Weekly retention
- Monthly retention

Metric definitions should be selected according to the product's natural usage frequency.

---

# 7. Cohort Retention Methodology

Users are grouped by signup month.

Successful transaction activity is evaluated by the number of calendar months elapsed since the cohort month.

The output includes:

```text
M0
M1
M2
M3
M4
M5
```

### Interpretation

Cohort analysis helps determine whether retention patterns differ across user generations.

### Incomplete Cohorts

Recent cohorts may not have had enough time to reach later lifecycle months.

Missing future observations should not be interpreted as zero retention.

---

# 8. KYC Incident Investigation

The incident investigation uses segmentation across:

- Device type
- App version
- KYC status
- Failure reason
- Time

The investigation identified Android 5.4 as an underperforming segment.

The affected segment showed:

- Lower KYC completion
- Elevated document-upload errors

This combination provides a plausible product-quality hypothesis.

### Causal Limitation

The analysis does not prove that the app version alone caused the observed decline.

Technical logs, release diagnostics, controlled rollout evidence, or additional causal analysis would be required for stronger causal attribution.

---

# 9. Incident Impact Estimation

Android 5.3 is used as a reference baseline for Android 5.4.

The counterfactual calculation is:

```text
Expected Completions
=
Android 5.4 KYC Attempts
×
Android 5.3 Completion Rate
```

Estimated completion difference:

```text
Expected Completions
−
Actual Android 5.4 Completions
```

Estimated downstream activated-user difference:

```text
Estimated Completion Difference
×
Observed Post-KYC Activation Rate
```

### Results

The analysis estimated:

```text
1,084 additional KYC completions
624 additional activated users
```

at reference performance.

### Interpretation

These are:

> Counterfactual estimates

They are not:

> Proven causal losses

The estimate assumes Android 5.3 is a reasonable performance reference for Android 5.4.

---

# 10. Acquisition Quality Methodology

Acquisition channels are evaluated using:

- User volume
- KYC completion
- Activation
- D30 retention

A composite score is created:

```text
Acquisition Quality Score
=
40% × Activation Rate
+
40% × D30 Retention Rate
+
20% × KYC Completion Rate
```

### Purpose

The score provides a simple prioritization framework for comparing downstream acquisition quality.

### Limitation

The weighting is a product decision rather than an objective statistical truth.

Different businesses may assign different weights based on:

- Revenue
- Customer acquisition cost
- Lifetime value
- Strategic priorities

---

# 11. Experiment Design

The KYC experiment compares:

```text
Control
vs
Treatment
```

## Primary Metric

KYC Completion Rate

## Guardrail Metric

Support Contact Rate

## Downstream Metric

Activation Rate

The primary decision should be based on the predefined primary metric while considering guardrail health and experiment validity.

---

# 12. Experiment Validation

Before evaluating treatment effects, the analysis checks:

- Number of experiment users
- Available variants
- Duplicate assignments
- Allocation balance

The experiment contained:

```text
6,032 users
```

with:

```text
3,102 control
2,930 treatment
```

No duplicate experiment users were identified.

---

# 13. Sample Ratio Mismatch

The intended experiment allocation was:

```text
50% Control
50% Treatment
```

A chi-square goodness-of-fit test was used to compare observed allocation with the expected split.

Result:

```text
Chi-square = 4.9045
P-value = 0.0268
```

At a 5% significance threshold, this produces a sample-ratio-mismatch warning.

### Interpretation

An SRM warning does not automatically prove the experiment is invalid.

It indicates that the assignment imbalance should be investigated.

Potential causes include:

- Assignment logic
- Eligibility filtering
- Instrumentation issues
- Missing data
- Post-assignment exclusions
- Random variation

No specific cause is assumed without additional evidence.

---

# 14. Primary Metric Statistical Test

The experiment compares two proportions:

```text
Control KYC Completion Rate
vs
Treatment KYC Completion Rate
```

A two-proportion z-test is used.

## Null Hypothesis

```text
H0:
Treatment completion rate
=
Control completion rate
```

## Alternative Hypothesis

```text
H1:
Treatment completion rate
≠
Control completion rate
```

A two-sided test is used because the analysis evaluates whether the treatment differs from control rather than assuming improvement in advance.

---

# 15. Experiment Results

Observed results:

```text
Control:
60.67%

Treatment:
62.22%
```

Absolute lift:

```text
+1.55 percentage points
```

Relative lift:

```text
+2.55%
```

Statistical result:

```text
Z-score:
1.2343

P-value:
0.2171

95% Confidence Interval:
[-0.91, +4.00] percentage points
```

---

# 16. Statistical Interpretation

The result is not statistically significant at:

```text
alpha = 0.05
```

because:

```text
p-value > 0.05
```

The confidence interval also includes zero.

Therefore, the data does not provide sufficient evidence to conclude that the treatment changed KYC completion.

### Important

A non-significant result does not prove that:

```text
Treatment effect = exactly zero
```

Possible interpretations include:

- No meaningful effect exists
- A smaller effect exists
- The experiment lacked sufficient power
- Experiment integrity issues affected the result

---

# 17. Experiment Decision Framework

The project does not use:

```text
Treatment metric > Control metric
=
Ship
```

Instead, the decision considers:

```text
Metric Direction
+
Statistical Evidence
+
Confidence Interval
+
Guardrail Health
+
Experiment Integrity
```

For the PulsePay experiment:

- Primary metric moved positively
- Result was not statistically significant
- Confidence interval included zero
- SRM warning was detected

Therefore:

> Do not declare the treatment a winner.

---

# 18. Reproducibility

The project separates the analytical workflow into:

## Data Generation

```text
python/data_generation/
```

## SQL Analysis

```text
sql/02_analysis/
```

## Experiment Analysis

```text
sql/03_experiments/
python/analysis/
```

## Dashboard Semantic Layer

```text
sql/04_dashboard/
```

## Final Analytical Exports

```text
data/processed/final_results/
```

This structure separates:

```text
Raw Data
→ Analysis Logic
→ Reusable Views
→ Statistical Analysis
→ Dashboard Outputs
```

---

# 19. Data Ethics and Disclosure

The dataset is entirely synthetic.

PulsePay is fictional.

No real:

- Customer data
- Financial information
- KYC information
- Personally identifiable information

is used.

The project is intended to demonstrate analytical methodology, technical implementation, product reasoning, and communication.

---

# 20. Key Limitations

## Synthetic Data

The findings are intentionally generated for portfolio demonstration.

## Observational Analysis

Retention relationships do not establish causality.

## Counterfactual Impact

Incident impact depends on the assumption that Android 5.3 is an appropriate reference.

## Experiment SRM

The assignment imbalance should be investigated before relying on the experiment for rollout decisions.

## Experiment Power

A non-significant result may reflect insufficient statistical power rather than the complete absence of an effect.

---

# Final Analytical Principle

The project follows one central principle:

> Product analytics should not stop at reporting what happened.

The analytical workflow should move toward:

```text
What happened?
      ↓
Where did it happen?
      ↓
Why might it have happened?
      ↓
How large might the impact be?
      ↓
What evidence do we have?
      ↓
What should the product team do next?
```