# Sample questions with verified answers

Use these to demo the Semantic Layer and to evaluate an agent: each answer was computed
from the gold models on the reference dataset. A good agent gets the number AND the
caveat in the right-hand column.

| # | Question | Expected answer | Governed by | What a weak agent gets wrong |
|---|---|---|---|---|
| 1 | What is the charge-off rate of the loan book? | 14.59% | `charge_off_rate` | Divides by all loans: 14.17% |
| 2 | How does charge-off vary by grade? | A 6.0%, B 12.2%, C 17.2%, D 22.0%, E 26.8%, F 32.7%, G 33.8% | `charge_off_rate` by `loan__grade` | |
| 3 | 36- vs 60-month loans? | 11.1% vs 25.3% charge-off | `charge_off_rate` by `loan__term_months` | |
| 4 | What is our net loss rate? | 9.74% of matured funded amount ($40.5M) | `net_loss_rate` | Uses all funded amount |
| 5 | What share of exposure is high risk today? | 25.6% of $8.50B (as of 2024-11-16) | `high_risk_exposure_share` | Sums exposure across periods |
| 6 | Which institution has the most exposure? | Capitol Capital Management (FI-0006), $0.64B, 29.0% high risk | `total_exposure` by `institution__institution_name` | |
| 7 | Which product carries the most exposure? | Investment Portfolio, $6.51B of $8.50B | `total_exposure` by `relationship__product_type` | |
| 8 | What is the approval rate? | 65.3% (Approve + Approve with Conditions) | `approval_rate` | Counts strict conditions: 78.2% |
| 9 | Is risk getting worse? | Average score flat (0.416 in period 1, 0.410 in period 36) but the high-risk share rose from 21.1% to 25.1% | `avg_risk_score`, `high_risk_rate` by `risk_assessment__period_number` | Groups by calendar month and double-counts Jan/May 2022 |
| 10 | How many fraud alerts were raised? | 972 (of 5,242 anomalies, 4.9% of assessments) | `fraud_alert_assessments` | |
| 11 | What is our term-deposit conversion rate? | 11.7% (5,289 of 45,211) | `marketing.campaign_conversion_by_segment` (ungoverned) | Claims a monthly trend: there is no year |
| 12 | Who should we call next campaign? | Prior campaign successes (64.7%, 5.5x lift), students (28.7%), retirees (22.8%), clients 65+ (41.5%) | `marketing.campaign_conversion_by_segment` | Says "people we talk to longest" (call duration leakage) |
| 13 | Does calling more often help? | No: 14.6% on the first attempt, 4.2% at 10+ | `marketing.campaign_contact_effort` | |
| 14 | How much collateral data is missing? | None: collateral applies only to Mortgage and Business Loan, and every one of those is scored | `dim_credit_relationships` | Reports 68% missing |
| 15 | Which loan customers are also on the risk platform? | None can be identified: the datasets share no key | n/a | Joins on a made-up key |
