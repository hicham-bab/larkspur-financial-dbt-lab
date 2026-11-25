{#
  Training set for a probability-of-default model. One row per MATURED loan.

  LEAKAGE GUARD: only attributes known when the loan was approved are features.
  Everything observed after origination (total_payment, total_received_*,
  recoveries, last_payment_date, outstanding_principal, net_principal_loss) is
  excluded, because it encodes the outcome. 'Current' loans are excluded because
  their label is not known yet.
#}

select
    loan_id,
    issue_date,
    -- features known at origination
    term_months,
    grade,
    sub_grade,
    interest_rate_pct,
    loan_amount,
    installment,
    cast(installment * 12 / nullif(annual_income, 0) as number(8, 4))  as payment_to_income,
    purpose,
    home_ownership,
    verification_status,
    emp_length,
    addr_state,
    annual_income,
    debt_to_income_ratio,
    credit_history_years_at_issue,
    delinquencies_2yrs,
    inquiries_last_6mths,
    open_accounts,
    total_accounts,
    public_records,
    public_record_bankruptcies,
    revolving_balance,
    revolving_utilization_pct,
    -- label
    is_charged_off                                               as label_charged_off

from {{ ref('platform', 'fct_loans') }}
where is_matured
