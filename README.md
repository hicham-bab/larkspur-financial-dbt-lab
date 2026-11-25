# Financial Services: dbt Mesh lab with a context layer

**Larkspur Financial** runs three businesses whose data arrives through one Fivetran
connector: a shared credit-risk platform used by 20 member institutions, a consumer
lending book, and a retail bank's term-deposit campaign. This lab turns the eight raw
tables into a governed dbt Mesh with a Semantic Layer and a context layer, so that an AI
agent can answer questions about it correctly and without guessing.

This is the project from the Fivetran, dbt Labs and Snowflake webinar *Agent-Assisted Data
Engineering*. It builds on the [dbt_scalefree_webinar](https://github.com/hicham-bab/dbt_scalefree_webinar)
reference project (AI readiness: governance, structured metadata and the Semantic Layer),
moved from synthetic seed data to the **Fivetran Financial Services** industry source.

Stack: Fivetran (Google Cloud PostgreSQL connector) + Snowflake + dbt v2 on the dbt platform +
[datavault4dbt](https://github.com/ScalefreeCOM/datavault4dbt) (Scalefree) for the Data Vault 2.0
layer + [dbt_semantic_view](https://github.com/Snowflake-Labs/dbt_semantic_view) (Snowflake Labs)
for Snowflake semantic views.

**Quickstart:** run [`setup/snowflake_setup.sql`](setup/snowflake_setup.sql) in a Snowsight
worksheet to load the data, then connect your copy of this repo to the dbt platform and
build `platform`. Details in [Setup](#setup).

---

## Why this lab exists

Raw financial data is full of traps that a person learns in a week and an agent never
learns unless someone writes them down. Every trap below was found by profiling the real
connector data, and each one is fixed in a model, guarded by a test, and written into the
context layer.

| Trap in the raw data | What a naive answer gets wrong | Where it is handled |
|---|---|---|
| "Monthly" risk assessments are 30 days apart | Grouping by calendar month double-counts January and May 2022 and skips February | `period_number`, `assert_assessment_periods_are_30_days_apart` |
| Two meanings of "approved" | 78.2% instead of the source system's 65.3% | `approval_rate` vs `any_approval_rate` |
| Current loans in the charge-off denominator | 14.17% instead of 14.59%, and the 2011 vintage looks better than it is | `charge_off_rate` on matured loans |
| Blank collateral, liquidity and cash-flow scores | "68% of collateral data is missing" (it is not applicable to unsecured products) | `assert_not_applicable_measures_follow_product` |
| `Nov-69` read as 2069 | 127 borrowers with a credit line opened after their loan | `int_loans`, `assert_credit_line_opened_before_loan` |
| Call duration in the campaign data | "Long calls drive subscriptions" (duration is known only after the call) | excluded from `term_deposit_propensity_features` |
| SSNs and licence numbers in the loan table | PII in gold tables and agent answers | never loaded into a satellite, tagged in sources |
| Four id spaces that look alike | Joining loan borrowers to risk-platform customers | stated in descriptions and agent rules |

Full numbers: [`context/data_caveats.md`](context/data_caveats.md).

---

## Architecture

```
  Fivetran: Google Cloud PostgreSQL -> Snowflake <LAB>_LANDING.<schema>_FINANCIAL_SERVICES
                                   |
                                   v
  +-----------------------------------------------------------------------+
  | PLATFORM (producer)                                                    |
  |  01_staging/      8 datavault4dbt stages: hash keys, hash diffs        |
  |  02_raw_vault/    6 hubs, 2 links, 10 satellites (v0 + v1)             |
  |  03_intermediate/ 11 views: business rules applied on the vault        |
  |  04_marts/core/   8 public, contract-enforced gold tables              |
  |     dim_customers  dim_institutions  dim_credit_relationships          |
  |     fct_risk_assessments (incremental)  fct_loans                      |
  |     fct_campaign_contacts  fct_product_recommendations  dim_date       |
  |  05_semantic_layer/ 5 semantic models, 28 metrics (8 ratios)          |
  |  06_semantic_views/ 3 Snowflake semantic views for Cortex agents       |
  |  tests/          7 singular tests, one per verified caveat             |
  +-----------------------------------------------------------------------+
           |  ref('platform', ...)    |                       |
           v                          v                       v
  +-------------------+   +----------------------+   +---------------------------+
  | FINANCE           |   | MARKETING            |   | DATA_SCIENCE              |
  | loan vintages     |   | campaign conversion  |   | loan_default_features     |
  | exposure by inst. |   | contact effort       |   | term_deposit_propensity   |
  | risk by period    |   | recommendation funnel|   | relationship trajectory   |
  | concentration     |   | customer segments    |   | (leakage-guarded)         |
  +-------------------+   +----------------------+   +---------------------------+
                                   |
                                   v
  Context layer: dbt metadata + context/ docs + Fivetran Context Layer (AGENTS.*)
```

| Project | Models | Access | Owner group |
|---|---|---|---|
| `platform` | 8 stages, 28 raw vault, 11 intermediate, 8 marts | marts `public`, contracts enforced | `credit_risk`, `lending`, `marketing` |
| `finance` | 4 marts, 8 metrics | `protected` | finance team |
| `marketing` | 5 marts, 4 metrics | `protected` | marketing team |
| `data_science` | 3 feature sets | `protected` | data science team |

---

## Data Vault layer

The platform follows the Scalefree reference project's layering, built with datavault4dbt (pinned in
`platform/packages.yml`):

| Layer | What happens | Example |
|---|---|---|
| `01_staging/<system>/` | `datavault4dbt.stage`: hash keys, hash diffs, `ldts` from `_fivetran_synced`, `rsrc` per source system, `is_deleted` from `_fivetran_deleted`. No cleaning | `stg__risk_platform__risk_assess_customers` |
| `02_raw_vault/` | Insert-only hubs, links and satellites (`_v0` incremental, `_v1` view with `is_current`). Values exactly as Fivetran delivered them | `customer_h`, `customer_institution_l`, `assessment_customer_institution_nl`, `customer_risk_platform_p_s_v1` |
| `03_intermediate/` | Business rules on the current satellite rows: types, sentinels to NULL, Mon-YY dates, the century fix, soft deletes and ghost records removed | `int_loans`, `int_risk_assessments` |
| `04_marts/core/` | The public, contract-enforced gold tables the consumers and agents use | `fct_loans`, `dim_credit_relationships` |
| `05_semantic_layer/` | Ratio metrics over the simple metrics that sit next to each mart | `approval_rate`, `charge_off_rate` |
| `06_semantic_views/` | Snowflake semantic views built by dbt over the core marts, with the same metric definitions | `sv_credit_risk`, `sv_lending_book`, `sv_term_deposit_campaign` |

Source systems: `risk_platform` (5 tables), `lending` (`loan`), `bank_marketing`
(`predict_term_deposit`) and `recommendations` (`fpr_records`). Personal data sits in its own
`_p_s` satellites (`customer_name`, `customer_email`), as in the reference project's `customer_crm_p_s`.
The loan table's identity columns are in no hash diff and no satellite, so dbt never
persists them. `fpr_records.customer_id` is a different id space from `customer_h`, so it
stays a satellite attribute rather than becoming a link.

## Try it: extend the vault with dbt Wizard

`platform/seeds/raw_customer_complaints.csv` is a complaints-handling extract that is
deliberately not modeled yet. Every complaint points at a real customer x institution
relationship. Ask dbt Wizard (which reads the datavault4dbt skills in
`platform/.agents/skills/`) to add it to the vault: a stage, a `complaint_h` hub, a link to
`customer_h` and `institution_h`, and a satellite. Then expose complaint counts on
`dim_credit_relationships`.

## Semantic Layer per project

Each project owns the metrics of the models it maintains:

| Project | Metrics | Built on |
|---|---|---|
| `platform` | 28 (8 ratios): risk, approval, exposure, lending, campaign | the core marts |
| `finance` | `vintage_*` (incl. `vintage_charge_off_rate`), `period_*` | `fct_loan_vintage_performance`, `risk_trend_by_period` |
| `marketing` | `recommendations_*`, `recommendation_acceptance_rate` | `recommendation_activity_daily` |

The consumer ratios reproduce the platform definitions: `vintage_charge_off_rate` over all
vintages is 14.59%, exactly the platform's `charge_off_rate`.

## Snowflake semantic views

`platform/models/06_semantic_views/` builds three Snowflake semantic views in the
`semantic` schema with the `semantic_view` materialization from
[dbt_semantic_view](https://github.com/Snowflake-Labs/dbt_semantic_view). Because dbt builds
them, they appear in dbt lineage, reference the contract-protected marts, and carry the same
definitions as the dbt Semantic Layer, so a Snowflake agent (Cortex Analyst, Cortex Agents,
Snowflake CoWork or Snowflake CoCo) and a dbt Semantic Layer query return the same number.

```sql
select * from semantic_view(
    <your PROD database>.SEMANTIC.SV_CREDIT_RISK
    dimensions institutions.region, assessments.period_number
    metrics assessments.high_risk_rate, relationships.total_exposure_usd
);
```

---

## The data

| Source table | Rows | Becomes |
|---|---|---|
| `risk_assess_customers` | 1,000 | `dim_customers` |
| `risk_assess_financial_institutions` | 20 | `dim_institutions` |
| `risk_assess_risk_profiles` + `risk_assess_performance_metrics` | 2,948 each | `dim_credit_relationships` |
| `risk_assess_monthly_assessments` | 106,128 | `fct_risk_assessments` |
| `loan` | 39,717 | `fct_loans` |
| `predict_term_deposit` | 45,211 | `fct_campaign_contacts` |
| `fpr_records` | 751 | `fct_product_recommendations` |

The files are in [`data/financial_services/`](data/financial_services/) as gzipped CSV, exported
from the Fivetran Financial Services source as Fivetran lands it. `loan` follows the public
Lending Club loan data (2007 to 2011); its borrower identity columns (`ssn`,
`social_security_number`, `ssnumber`, `ssnumber1`, `dl`, `drivers_license`) and free-text
fields (`emp_title`, `title`, `c_desc`, `c_url`) are shipped empty. `predict_term_deposit`
is the UCI Bank Marketing dataset (Moro, Cortez and Rita, 2014, CC BY 4.0). The risk
platform and recommendation tables are synthetic, and names and emails in them are fictional.

---

## Governance features

- **Contracts** on all 8 public platform marts, with data types taken from the built
  tables. A type change or a dropped column fails the build before a consumer sees it.
- **Access and groups.** Platform marts are `public`; consumer models are `protected`.
  Groups `credit_risk`, `lending` and `marketing` own the marts.
- **Structured metadata.** Every model carries `meta`: `owner`, `domain`, `tier`,
  `pii_contains`, `pii_columns`, `freshness_sla`, `semantic_layer_enabled`. PII columns
  carry `meta: {pii: true}`, in sources and in models.
- **PII handled at the edge.** Six identity columns in the loan source are tagged in
  `_sources.yml` and never selected. In production, block or hash them in the Fivetran
  connector's schema settings so they never land at all.
- **Semantic Layer.** 28 governed metrics, including the definitions that disagree in
  the raw data (`approval_rate` vs `any_approval_rate`, `charge_off_rate` on matured
  loans).
- **Tests as documentation.** Each caveat in the context layer has a test that fails
  if it stops being true.
- **Mesh reconciliation.** `finance/tests/assert_vintages_reconcile_to_platform.sql`
  proves the consumer's totals equal the producer's.

---

## Context layer

Three layers, all in git, described in [`context/README.md`](context/README.md):

1. **dbt metadata:** descriptions, meta, contracts, PII tags, Semantic Layer. Read by
   the dbt MCP server and dbt Wizard.
2. **[`context/`](context/):** agent instructions, verified caveats, glossary, and
   15 sample questions with verified answers (a walkthrough and an agent eval set).
3. **Fivetran Context Layer:** `context_layer/publish_context_layer.py` loads models,
   columns, lineage and metrics (with SQL recipes) into the `AGENTS.DBT_*` tables under
   `PROJECT = 'finserv_mesh_lab'`, and adds this project's routing note to `AGENTS.ROOT`.

---

## Setup

### 0. Prerequisites

- A Snowflake account where you can use `ACCOUNTADMIN` (a free trial works).
- A dbt platform account. Cross-project `ref` (dbt Mesh) needs an Enterprise or
  Enterprise+ plan, and the Semantic Layer needs Starter or above. On a smaller plan you
  can still build and explore `platform` on its own.
- Your own copy of this repository: click **Use this template** or fork it.

### 1. Load the source data (about a minute)

Open a Snowsight worksheet, paste [`setup/snowflake_setup.sql`](setup/snowflake_setup.sql)
and choose **Run all**. It creates `LARKSPUR_ROLE`, the `LARKSPUR_WH` warehouse, the
`LARKSPUR_LANDING`, `LARKSPUR_DEV` and `LARKSPUR_PROD` databases, and loads the eight
source tables into `LARKSPUR_LANDING.POSTGRES_FINANCIAL_SERVICES` straight from this public
repository. The last query should show 198,723 rows in total.

The tables match what the Fivetran Google Cloud PostgreSQL connector lands, including
`_fivetran_synced` and `_fivetran_deleted`. **Using Fivetran instead?** Land the Financial
Services source with your connector, set `source_schema` in `platform/dbt_project.yml` to
the schema it created, and point `source_database` at its database if it is not your target
database with `_DEV`/`_PROD` swapped for `_LANDING`.

### 2. dbt platform: four projects

1. Create a Snowflake connection: your account identifier, role `LARKSPUR_ROLE`,
   warehouse `LARKSPUR_WH`. Development credentials use database `LARKSPUR_DEV`; the
   production environment uses `LARKSPUR_PROD`.
2. Create four projects on your copy of the repository, each with its **project
   subdirectory** set to `platform`, `finance`, `marketing` or `data_science`.
3. In `platform`, run `dbt deps` (installs datavault4dbt and dbt_semantic_view), then
   `dbt build`. Sources resolve to `LARKSPUR_LANDING` automatically.
4. Create a **production** environment and a job for `platform` (`dbt build`) and run it
   once. Cross-project refs resolve against the producer's production environment, so the
   consumers cannot build until it has succeeded.
5. In each consumer, `dependencies.yml` already declares `platform`: run `dbt build`.

Prefer the command line? `platform` also builds with the dbt v2 CLI against the same
databases; copy [`profiles.example.yml`](profiles.example.yml) to `~/.dbt/profiles.yml`.
The consumers need the dbt platform to resolve cross-project refs.

### 3. Semantic Layer

Configure the Semantic Layer on the production environment of `platform`, and of `finance`
and `marketing` for their own metrics. The time spine is `dim_date`. The Snowflake semantic
views in `LARKSPUR_PROD.SEMANTIC` are built by the `platform` job and need no extra setup.

### 4. Fivetran Context Layer (optional)

Only if your Snowflake account has the Fivetran Context Layer (`AGENTS.*` tables):

```bash
python3 context_layer/publish_context_layer.py \
    --agents-schema <DB>.AGENTS \
    --gold-database LARKSPUR_PROD \
    --raw-schema LARKSPUR_LANDING.POSTGRES_FINANCIAL_SERVICES
```

Review `context_layer/generated/load_context_layer.sql`, then run it with a role that
can write to `AGENTS`. It only touches `PROJECT = 'finserv_mesh_lab'` rows and this
project's section of the routing note.

### Clean up

```sql
use role accountadmin;
drop database if exists larkspur_dev;
drop database if exists larkspur_prod;
drop database if exists larkspur_landing;
drop warehouse if exists larkspur_wh;
drop integration if exists larkspur_github;
drop role if exists larkspur_role;
```

---

## Suggested walkthrough

| Step | Show | Point |
|---|---|---|
| 1. Raw data | `risk_assess_monthly_assessments` dates, `loan.int_rate`, `fpr_records` placeholders | Fivetran delivers it reliably; it is still raw |
| 2. Ask an agent with no context | "What is our approval rate?", "monthly risk trend" | Plausible and wrong |
| 3. Data Vault | `stg__lending__loan` (hashing, PII kept out of every satellite), `loan_h` + `loan_lending_n_s_v1`, then `int_loans` (century fix) and `int_risk_profiles` (blank is not missing) | The vault keeps what the source said; business rules are applied once, on top |
| 4. Contracts and Mesh | Break a contract on `fct_loans`; build `finance` with `ref('platform', ...)` | Producers can change safely; consumers get guarantees |
| 5. Semantic Layer | `approval_rate` vs `any_approval_rate`; `charge_off_rate` | One definition, every tool |
| 6. Context layer | `context/agent_instructions.md`, then `SELECT * FROM AGENTS.ROOT` | The same rules reach every agent |
| 7. Ask again | Questions 1, 8, 9 and 12 from `context/sample_questions.md` | Right number, right caveat |

---

## Conventions

Written for dbt v2 (and compatible with dbt v1.9+): no `config-version`, `cast()` only
(no `::`), `arguments:` on generic tests, `require-dbt-version: [">=1.9.0"]`. The platform
uses two packages, datavault4dbt and dbt_semantic_view: run `dbt deps` in `platform/` first.

## File map

```
platform/       producer: 01_staging, 02_raw_vault, 03_intermediate, 04_marts, 05_semantic_layer,
                06_semantic_views, tests, seeds (dev-workflow source), .agents/skills (datavault4dbt agent skills)
finance/        consumer: lending and credit-risk finance marts
marketing/      consumer: campaign and recommendation marts
data_science/   consumer: leakage-guarded feature sets
context/        agent instructions, caveats, glossary, sample Q&A, routing template
context_layer/  publish_context_layer.py (Fivetran Context Layer loader)
data/           the 8 source tables (gzipped CSV, Fivetran landing shape)
setup/          snowflake_setup.sql: role, warehouse, databases and data load
```
