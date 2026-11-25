{{ config(materialized='semantic_view', schema='semantic', static_analysis='off') }}
-- Snowflake semantic view over the consumer lending book. charge_off_rate divides by
-- MATURED loans, as the dbt Semantic Layer does: current loans have no outcome yet.
-- The loan source's identity columns never reach fct_loans, so they cannot appear here.

tables (
    loans as {{ ref('fct_loans') }}
        primary key (loan_id)
        comment = 'One row per consumer loan (about 40K, 2007 to 2011).'
)

facts (
    loans.funded_amount_usd as loans.funded_amount,
    loans.loan_amount_usd as loans.loan_amount,
    loans.interest_rate as loans.interest_rate_pct
        comment = 'Interest rate in percent, e.g. 10.62.',
    loans.net_principal_loss_usd as loans.net_principal_loss,
    loans.annual_income_usd as loans.annual_income
)

dimensions (
    loans.issue_date as loans.issue_date,
    loans.issue_year as loans.issue_year,
    loans.grade as loans.grade
        with synonyms = ('credit grade', 'loan grade'),
    loans.sub_grade as loans.sub_grade,
    loans.purpose as loans.purpose
        with synonyms = ('loan purpose'),
    loans.term_months as loans.term_months,
    loans.home_ownership as loans.home_ownership,
    loans.verification_status as loans.verification_status,
    loans.emp_length as loans.emp_length
        comment = 'Employment length band.',
    loans.addr_state as loans.addr_state
        with synonyms = ('state'),
    loans.loan_status as loans.loan_status,
    loans.is_matured as loans.is_matured
        comment = 'Fully Paid or Charged Off: the loan has a final outcome.',
    loans.is_charged_off as loans.is_charged_off
)

metrics (
    loans.loan_count as count(loans.loan_id),
    loans.total_funded_amount as sum(loans.funded_amount_usd),
    loans.matured_loans as count_if(loans.is_matured),
    loans.charged_off_loans as count_if(loans.is_charged_off),
    loans.charge_off_rate as count_if(loans.is_charged_off) / nullif(count_if(loans.is_matured), 0)
        with synonyms = ('default rate', 'loss rate by count')
        comment = 'Governed definition: charged-off loans over MATURED loans (14.59%). Never over all loans (14.17%).',
    loans.net_loss_rate as sum(loans.net_principal_loss_usd) / nullif(sum(iff(loans.is_matured, loans.funded_amount_usd, 0)), 0)
        comment = 'Net principal loss after recoveries over funded amount of matured loans.',
    loans.avg_interest_rate as avg(loans.interest_rate),
    loans.avg_annual_income as avg(loans.annual_income_usd)
)

comment = 'Larkspur Financial consumer lending book. Built and tested by dbt (fct_loans, enforced contract).'
