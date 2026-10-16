# Higher-Ed Model Validation Notes

Practitioner notes on validating predictive models in higher education — where the data is longitudinal, the stakes are student outcomes, and the most common failure mode is **leakage through time**.

These notes are written from the perspective of an institutional research analyst who has to defend a model to a provost, not just to a cross-validation score.

## Contents

| Note | Topic |
|---|---|
| `temporal_validation.md` | Train/validate/test splits across terms, leakage examples, precision/recall tradeoffs, threshold selection. The core methodology. |
| `leakage_examples.md` | A catalog of real-world leakage patterns in student-success modeling — what they look like and how to catch them. |

## Key positions

1. **Random k-fold CV is wrong for student data.** Terms are not exchangeable. Validate forward in time or your performance estimates are fiction.
2. **Leakage is the default, not the exception.** Cumulative GPA, "ever" flags, and post-outcome features leak constantly. Assume guilt until proven innocent.
3. **Thresholds are policy decisions.** A risk model's cutoff decides who gets an advisor's limited hours. Precision/recall is an ethics conversation, not just a metric.
4. **Validate the deployment, not the lab.** Population stability, calibration drift, and subgroup performance matter more than a third decimal of AUC.

## Scope

Notes, not a library. No code here trains models — the companion repos (`higher-ed-retention-dashboard-demo`, `student-success-data-quality-checks`) carry the data and QA side. All examples use synthetic scenarios.
