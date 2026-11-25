# Data caveats (verified)

Every fact on this page was checked by query against a Fivetran-landed copy of the
Financial Services source (Google Cloud PostgreSQL connector, Snowflake destination)
before any model was written. If a lab attendee's numbers differ, their connector
landed different data; re-run the profiling queries rather than trusting this page.

## The three businesses in one schema

The eight source tables are three unrelated datasets that happen to share a connector.

| Domain | Tables | Grain | Joins to the others? |
|---|---|---|---|
| Credit risk platform | `risk_assess_customers`, `risk_assess_financial_institutions`, `risk_assess_monthly_assessments`, `risk_assess_risk_profiles`, `risk_assess_performance_metrics` | 1,000 customers, 20 institutions, 2,948 relationships, 106,128 assessments | Fully, on `customer_id` + `institution_id` (zero orphans) |
| Consumer lending | `loan` | 39,717 loans | No. Public Lending Club data, its own borrowers |
| Retail bank marketing | `predict_term_deposit` | 45,211 contacts | No. Public UCI Bank Marketing data |
| Product recommendations | `fpr_records` | 751 recommendations | No. `CUST_000123` ids, never `CUST-0123` |

An agent that joins `fct_loans` to `dim_customers` has invented a relationship.

## Credit risk platform

| Fact | Value |
|---|---|
| Relationships | 2,948 customer x institution pairs; each holds exactly one product |
| Assessment periods | 36, every relationship assessed in every one (2,948 x 36 = 106,128) |
| Period cadence | Exactly 30 days apart, 2022-01-01 to 2024-11-16 |
| Calendar months | January and May 2022 each contain two periods; February 2022 contains none. Grouping by calendar month double-counts two months and drops one. Use `period_number` |
| Source `month` / `year` columns | Derived from the date, so they inherit the problem. Loaded into the raw vault as delivered, dropped in `int_risk_assessments` |
| `date` column | Lands as VARCHAR (`2022-01-31`), cast cleanly on all rows |
| Risk level | A band of the score: Very Low 0.01-0.20, Low 0.20-0.40, Moderate 0.40-0.60, High 0.60-0.80, Very High 0.80-0.99. Bounds inclusive: 54 assessments score exactly 0.200 and are labelled Very Low |
| Booleans | `is_anomaly`, `is_homeowner`, `has_previous_bankruptcy` land as the strings `'True'` / `'False'` |
| `anomaly_type` | The string `'None'` when there is no anomaly. 4.9% of assessments are anomalies; 972 are Fraud Alerts |
| `risk_change_from_previous` | VARCHAR, empty on each relationship's first period (2,948 rows) |
| Showcase personas | `CUST-C001`..`CUST-C005` and `FI-C001`..`FI-C005` are hand-built story records (e.g. "High-Risk Short-Term Borrower"), 27,900 of the assessments involve them |
| Total exposure | $8,495,805,633.08, identical in profiles and performance metrics, and across customer, institution and relationship grains |

### Blank is not missing

`collateral_quality_score`, `liquidity_ratio` and `projected_cash_flow_rating` land
as VARCHAR and are empty on 2,005 / 2,160 / 2,054 profiles. The blanks follow the
product exactly, on every row:

| Measure | Populated for | Empty for |
|---|---|---|
| `collateral_quality_score` | Mortgage, Business Loan | everything unsecured |
| `liquidity_ratio` | Business Loan | everything else |
| `projected_cash_flow_rating` | Business Loan, Personal Loan | everything else |

These are "not applicable", not data-quality gaps. Reporting "68% of collateral scores
are missing" would be wrong. A singular test (`assert_not_applicable_measures_follow_product`)
fails if that ever stops being true.

### Two definitions of "approval rate"

`risk_assess_performance_metrics.approval_percentage` counts **Approve** and
**Approve with Conditions** only. **Approve with Strict Conditions** is not approved
in the source system. Recomputing it with `like 'Approve%'` is off by up to 86 points
for a single relationship. Across all assessments:

| Reading | Rate |
|---|---|
| `approval_rate` (source definition, governed) | 65.3% |
| `any_approval_rate` (includes strict conditions) | 78.2% |
| `denial_rate` | 21.8% |

`avg_risk_score` and `anomaly_percentage` in the same table do match the assessments.

## Consumer lending (`loan`)

| Fact | Value |
|---|---|
| Issue window | 2007-06 to 2011-12, observed in May 2016 (latest payment date) |
| Status | Fully Paid 32,950, Charged Off 5,627, Current 1,140 |
| Current loans | All 1,140 are 2011 vintage, so they distort exactly the newest cohort |
| Charge-off rate | 14.59% of matured loans (governed). 14.17% if you wrongly divide by all loans |
| Net loss rate | 9.74% of matured funded amount ($40.5M net principal loss) |
| Grade | Charge-off rises A 6.0% to G 33.8%; 36-month 11.1% vs 60-month 25.3% |
| Text-typed numbers | `int_rate` `'10.65%'`, `revol_util` `'83.7%'`, `term` `' 36 months'` |
| Sentinel | `pub_rec_bankruptcies` holds `'NA'` on 697 loans |
| Century bug | `earliest_cr_line` is `Mon-YY`; Snowflake reads `Nov-69` as 2069, putting 127 credit lines after the loan was issued. Fixed in `int_loans` (the raw vault keeps the source text) |
| Identity columns | `ssn`, `social_security_number`, `ssnumber`, `ssnumber1`, `dl`, `drivers_license` are populated on every row (placeholder values, 6 distinct). In no hash diff or satellite, so dbt never persists them; tagged PII in sources. Block or hash them in the Fivetran connector schema settings in production |
| Negative losses | 9 charged-off loans recovered more than was outstanding |

## Retail bank marketing (`predict_term_deposit`)

| Fact | Value |
|---|---|
| Contacts | 45,211; 5,289 subscribed (11.7%) |
| Time | Day and month only, no year. There is no time axis: compare segments, not periods |
| Sentinels | `'unknown'` in job (288), education (1,857), contact (13,020), poutcome (36,959); `pdays = -1` means never contacted before (36,954) |
| Leakage | `duration` (call length) is known only after the call. Under 60 s: 0.2% subscribe; over 600 s: 48%. Never a feature, never "the driver of conversion" |
| Strongest real signal | Previous campaign outcome = success: 64.7% conversion, 5.5x lift (1,511 clients) |
| Effort | Conversion falls with every extra attempt: 14.6% on the first contact, 4.2% at 10+ |

## Product recommendations (`fpr_records`)

| Fact | Value |
|---|---|
| Rows | 751, one per customer, recommendations 2024-04-28 to 2025-05-17 |
| Placeholders | `transaction_history`, `customer_product_interests`, `customer_product_usage`, `customer_product_usage_trend` hold `"Product Usage 42"`-style text in every row. Dropped |
| Accepted | 129 of 751 (17.2%) |
