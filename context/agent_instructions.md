# Agent instructions

For any AI agent answering questions over this project (dbt MCP server, dbt Wizard,
Snowflake Cortex, Databricks Genie, a Claude or GPT agent reading the Fivetran
Context Layer). Read `data_caveats.md` once; these rules are the short version.

## Route the question

1. **Governed number first.** If a Semantic Layer metric exists for it, use the
   metric (dbt MCP `query_metrics`, or the `recipe_sql` in `AGENTS.DBT_METRIC`).
   Say which metric you used.
2. **No metric?** Query the gold models: `core.*` (platform), `finance.*`,
   `marketing.*`, `data_science.*`. Say the number is ungoverned and name the table.
3. **Never** answer from staging views, the raw vault (`raw_vault.*`) or the raw Fivetran
   schema unless the question is about the raw data itself; their sentinels and types are
   not cleaned, and vault tables contain ghost records and every historical version.

## Hard rules

- **Three businesses, no shared keys.** Risk platform customers, loan borrowers,
  campaign contacts and recommendation customers are different people with different
  ids. Do not join them, and say so if a question assumes they are the same.
- **Periods, not months.** Trend risk data by `period_number` or `assessment_date`.
  Never group `fct_risk_assessments` by calendar month: January and May 2022 hold two
  periods each and February 2022 holds none.
- **Approval rate means the source definition.** `approval_rate` counts Approve and
  Approve with Conditions (65.3%). If the user clearly means "any approval", use
  `any_approval_rate` (78.2%) and say which one you used.
- **Charge-off rate uses matured loans.** Charged off / (Fully Paid + Charged Off) =
  14.59%. Do not divide by all loans; all 1,140 Current loans are 2011 vintage.
- **Exposure is a balance.** Sum it across relationships, customers, institutions or
  products; never across dates.
- **Blank is not missing.** NULL collateral, liquidity or cash-flow scores mean the
  measure does not apply to that product. Do not report them as data gaps.
- **Call duration is not a driver.** It is known only after the call. Never present
  it as what predicts or explains conversion.
- **No time trend for the campaign.** The source has no year. Compare segments.
- **PII.** Never return `customer_name` (or any name, email, SSN, licence number)
  in an answer. Aggregate. Identity columns of the loan source never reach gold.
- **Personas.** `CUST-C00x` and `FI-C00x` records are showcase personas; say so when
  they appear in an answer.
- **Dates.** The lending book ends in 2011 (observed May 2016), the risk platform
  ends 2024-11-16, recommendations end 2025-05-17. "This year" or "last month" has no
  answer here: say what the latest available period is.

## Phrases to avoid

| Do not say | Say instead |
|---|---|
| "monthly risk trend" | "risk trend by assessment period (30-day cadence)" |
| "default rate" for the loan book | "charge-off rate on matured loans" |
| "68% of collateral data is missing" | "collateral is only scored for secured products" |
| "longer calls drive subscriptions" | "previous campaign success is the strongest signal (5.5x lift)" |
