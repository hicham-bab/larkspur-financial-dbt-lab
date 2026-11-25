# Business glossary

Larkspur Financial is a fictional group that runs three businesses, each with its own
data: a **shared credit-risk platform** used by 20 member institutions, a **consumer
lending book**, and a **retail bank** that markets term deposits. Terms below are the
ones agents and analysts should use; the governed metric is named where one exists.

| Term | Meaning | Where it lives |
|---|---|---|
| Customer | A borrower on the risk platform (`CUST-0001`). Not a loan borrower and not a campaign contact | `dim_customers` |
| Institution | A member bank, credit union, insurer or asset manager using the platform (`FI-0001`) | `dim_institutions` |
| Relationship | One customer at one institution, holding one product. The unit of exposure | `dim_credit_relationships` |
| Assessment | One risk score of one relationship in one period | `fct_risk_assessments` |
| Assessment period | One of 36 scoring rounds, 30 days apart. Period 1 = 2022-01-01, period 36 = 2024-11-16. Not a calendar month | `period_number` |
| Risk score | 0 (safe) to 1. Banded into Very Low / Low / Moderate / High / Very High | `risk_score`, `risk_level` |
| High risk | Risk level High or Very High | metric `high_risk_rate` |
| Approved | Recommendation **Approve** or **Approve with Conditions**. Strict conditions are not approved | metric `approval_rate` |
| Any approval | Any recommendation starting with Approve, strict conditions included | metric `any_approval_rate` |
| Exposure | Amount at risk in a relationship, USD, at the latest assessment. A balance: sum across relationships, never across dates | metric `total_exposure` |
| High-risk exposure share | Exposure in relationships that are high risk at the latest assessment, over total exposure | metric `high_risk_exposure_share` |
| Secured product | Mortgage or Business Loan, the only products with collateral | `is_secured_product` |
| Showcase persona | Hand-built story record (`CUST-C001`..`C005`, `FI-C001`..`C005`). Name it as such in answers | `is_showcase_persona` |
| Loan vintage | The year a loan was issued | `issue_year` |
| Matured loan | Fully Paid or Charged Off. Only matured loans have a known outcome | `is_matured` |
| Charge-off rate | Charged-off loans over **matured** loans | metric `charge_off_rate` |
| Net principal loss | Funded amount minus principal repaid minus net recoveries, on charged-off loans | metric `total_net_principal_loss` |
| Net loss rate | Net principal loss over funded amount of matured loans | metric `net_loss_rate` |
| Campaign contact | A client called in the term-deposit campaign | `fct_campaign_contacts` |
| Conversion | Contact subscribed to the term deposit. 11.7% overall | `marketing.campaign_conversion_by_segment` |
| Lift | Segment conversion over overall conversion | `lift_vs_overall` |
| Leakage | A feature that is only known after the outcome (call duration; payments on a loan) | `data_science` models exclude them |
