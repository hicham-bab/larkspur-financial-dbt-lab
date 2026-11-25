## PROJECT = '{project_key}'
Larkspur Financial, a dbt Mesh of four projects (platform, finance, marketing, data_science) over the Fivetran Financial Services connector. Three unrelated businesses share no keys: a credit-risk platform for 20 member institutions (1,000 customers, 2,948 relationships, 36 assessment periods 2022-01-01 to 2024-11-16), a consumer loan book (39,717 loans issued 2007-2011, observed May 2016) and a term-deposit telemarketing campaign (45,211 contacts, no year recorded). Gold marts: {gold_schema}; consumer marts sit in the sibling FINANCE, MARKETING and DATA_SCIENCE schemas.
{n_models} models, {n_columns} documented columns, {n_edges} lineage edges, {n_metrics} metrics. Raw copy: {raw_schema}.
- Risk data is on a 30-day cadence: trend by period_number, never by calendar month (Jan and May 2022 hold two periods, Feb 2022 none).
- approval_rate counts Approve + Approve with Conditions only (65.3%); any_approval_rate adds strict conditions (78.2%). Say which one you used.
- charge_off_rate divides by matured loans (Fully Paid + Charged Off), never by all loans.
- total_exposure is a balance as of 2024-11-16: sum across relationships, never across dates.
- NULL collateral / liquidity / cash-flow scores mean "not applicable to the product", not missing data.
- Campaign call duration leaks the outcome; never present it as a driver. The campaign has no time axis.
- Never return customer_name or any identity column. CUST-C00x and FI-C00x are showcase personas.
