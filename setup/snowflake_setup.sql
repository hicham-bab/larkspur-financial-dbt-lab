-- Larkspur Financial: one-shot Snowflake setup
--
-- Run this whole worksheet in Snowsight ("Run all") as ACCOUNTADMIN, for example on a
-- Snowflake trial account. It creates:
--   role       LARKSPUR_ROLE (granted to you)
--   warehouse  LARKSPUR_WH (X-Small, auto-suspends after 60 seconds)
--   databases  LARKSPUR_LANDING (raw data), LARKSPUR_DEV and LARKSPUR_PROD (dbt targets)
--   schema     LARKSPUR_LANDING.POSTGRES_FINANCIAL_SERVICES with the 8 source tables
--
-- The tables have the same names, columns and types as the Fivetran Google Cloud
-- PostgreSQL connector would land, including _fivetran_synced and _fivetran_deleted, so
-- the dbt project runs unchanged. The data is read straight from this public GitHub
-- repository through a Snowflake Git integration: nothing to download or upload.
-- Borrower identity columns and free-text fields in LOAN are shipped empty.
--
-- If you land the data with your own Fivetran connector instead, skip this script and
-- set source_schema in platform/dbt_project.yml to your schema.

use role accountadmin;

-- 1. Role, warehouse and databases ------------------------------------------------------
create role if not exists larkspur_role;
set my_user = current_user();
grant role larkspur_role to user identifier($my_user);
grant role larkspur_role to role sysadmin;

create warehouse if not exists larkspur_wh
    warehouse_size = 'XSMALL' auto_suspend = 60 auto_resume = true initially_suspended = true;
grant usage, operate on warehouse larkspur_wh to role larkspur_role;

create database if not exists larkspur_landing;
create database if not exists larkspur_dev;
create database if not exists larkspur_prod;
grant ownership on database larkspur_landing to role larkspur_role copy current grants;
grant ownership on database larkspur_dev to role larkspur_role copy current grants;
grant ownership on database larkspur_prod to role larkspur_role copy current grants;
grant ownership on schema larkspur_landing.public to role larkspur_role copy current grants;
grant ownership on schema larkspur_dev.public to role larkspur_role copy current grants;
grant ownership on schema larkspur_prod.public to role larkspur_role copy current grants;

-- 2. Git integration to read the data files from GitHub -------------------------------
create api integration if not exists larkspur_github
    api_provider = git_https_api
    api_allowed_prefixes = ('https://github.com/hicham-bab/')
    enabled = true;
grant usage on integration larkspur_github to role larkspur_role;

use role larkspur_role;
use warehouse larkspur_wh;
create schema if not exists larkspur_landing.postgres_financial_services;
use schema larkspur_landing.postgres_financial_services;

create or replace git repository larkspur_repo
    api_integration = larkspur_github
    origin = 'https://github.com/hicham-bab/larkspur-financial-dbt-lab.git';
alter git repository larkspur_repo fetch;

create or replace file format larkspur_csv
    type = csv
    compression = gzip
    parse_header = false
    skip_header = 1
    field_optionally_enclosed_by = '"'
    null_if = ('\\N')
    empty_field_as_null = false
    timestamp_format = 'YYYY-MM-DD HH24:MI:SS.FF9 TZH:TZM';

-- 3. Source tables (Fivetran landing shape) ---------------------------------------------
create or replace table fpr_records (
    ctid_fivetran_id varchar,
    customer_transaction_value number(11,
    7),
    account_balance number(11,
    6),
    customer_product_affinity number(10,
    10),
    product_recommendation_status varchar,
    recommendation_score number(10,
    10),
    customer_product_affinity_trend varchar,
    customer_churn_probability number(10,
    10),
    product_terms varchar,
    customer_product_usage varchar,
    product_sales_amount number(11,
    7),
    product_id varchar,
    product_recommendation_date varchar,
    customer_product_usage_trend varchar,
    product_recommendation varchar,
    customer_product_interests varchar,
    customer_transaction_count number(38,
    0),
    transaction_history varchar,
    customer_satisfaction_score number(10,
    10),
    customer_lifecycle_stage varchar,
    product_sales_date varchar,
    product_name varchar,
    customer_segment varchar,
    record_id varchar,
    product_type varchar,
    customer_email varchar,
    customer_lifecycle_stage_transition_date varchar,
    customer_name varchar,
    customer_id varchar,
    _fivetran_deleted boolean,
    _fivetran_synced timestamp_tz
);

create or replace table loan (
    ctid_fivetran_id varchar,
    collection_recovery_fee number(13,
    9),
    acc_now_delinq number(38,
    0),
    drivers_license varchar,
    total_rec_int number(8,
    2),
    num_sats varchar,
    zip_code varchar,
    mths_since_recent_revol_delinq varchar,
    ssn varchar,
    ssnumber1 number(9,
    0),
    initial_list_status varchar,
    delinq_2yrs number(38,
    0),
    max_bal_bc varchar,
    id number(38,
    0),
    total_cu_tl varchar,
    last_credit_pull_d varchar,
    open_il_24m varchar,
    emp_length varchar,
    open_il_12m varchar,
    num_actv_rev_tl varchar,
    num_tl_op_past_12m varchar,
    open_rv_12m varchar,
    open_rv_24m varchar,
    mo_sin_old_il_acct varchar,
    home_ownership varchar,
    revol_util varchar,
    c_url varchar,
    num_op_rev_tl varchar,
    num_bc_tl varchar,
    grade varchar,
    loan_amnt number(38,
    0),
    annual_inc_joint varchar,
    ssnumber varchar,
    tot_hi_cred_lim varchar,
    issue_d varchar,
    mths_since_recent_bc_dlq varchar,
    mths_since_recent_inq varchar,
    inq_last_6mths number(38,
    0),
    verification_status_joint varchar,
    num_accts_ever_120_pd varchar,
    recoveries number(12,
    7),
    pub_rec_bankruptcies varchar,
    pymnt_plan varchar,
    out_prncp_inv number(7,
    2),
    mths_since_recent_bc varchar,
    term varchar,
    social_security_number varchar,
    mths_since_last_delinq varchar,
    num_tl_30dpd varchar,
    loan_status varchar,
    last_pymnt_amnt number(8,
    2),
    num_actv_bc_tl varchar,
    mths_since_last_major_derog varchar,
    emp_title varchar,
    total_rec_late_fee number(12,
    9),
    bc_open_to_buy varchar,
    addr_state varchar,
    mo_sin_rcnt_rev_tl_op varchar,
    num_il_tl varchar,
    total_bal_ex_mort varchar,
    chargeoff_within_12_mths varchar,
    num_rev_accts varchar,
    tot_cur_bal varchar,
    dl varchar,
    total_bc_limit varchar,
    out_prncp number(7,
    2),
    acc_open_past_24mths varchar,
    next_pymnt_d varchar,
    last_pymnt_d varchar,
    num_tl_90g_dpd_24m varchar,
    inq_fi varchar,
    total_acc number(38,
    0),
    int_rate varchar,
    avg_cur_bal varchar,
    annual_inc number(9,
    2),
    pct_tl_nvr_dlq varchar,
    open_acc_6m varchar,
    c_desc varchar,
    il_util varchar,
    funded_amnt_inv number(14,
    9),
    installment number(7,
    2),
    earliest_cr_line varchar,
    num_tl_120dpd_2m varchar,
    total_rec_prncp number(8,
    2),
    pub_rec number(38,
    0),
    tot_coll_amt varchar,
    percent_bc_gt_75 varchar,
    funded_amnt number(38,
    0),
    total_rev_hi_lim varchar,
    gid number(38,
    0),
    delinq_amnt number(38,
    0),
    bc_util varchar,
    mo_sin_rcnt_tl varchar,
    purpose varchar,
    application_type varchar,
    tax_liens varchar,
    verification_status varchar,
    title varchar,
    mths_since_last_record varchar,
    mo_sin_old_rev_tl_op varchar,
    inq_last_12m varchar,
    all_util varchar,
    policy_code number(38,
    0),
    dti number(5,
    2),
    num_bc_sats varchar,
    sub_grade varchar,
    member_id number(38,
    0),
    total_bal_il varchar,
    total_pymnt number(12,
    7),
    num_rev_tl_bal_gt_0 varchar,
    total_pymnt_inv number(8,
    2),
    mort_acc varchar,
    total_il_high_credit_limit varchar,
    revol_bal number(38,
    0),
    open_acc number(38,
    0),
    dti_joint varchar,
    open_il_6m varchar,
    mths_since_rcnt_il varchar,
    collections_12_mths_ex_med varchar,
    _fivetran_deleted boolean,
    _fivetran_synced timestamp_tz
);

create or replace table predict_term_deposit (
    ctid_fivetran_id varchar,
    loan varchar,
    gid number(38,
    0),
    education varchar,
    previous number(38,
    0),
    housing varchar,
    poutcome varchar,
    duration number(38,
    0),
    marital varchar,
    balance number(38,
    0),
    month varchar,
    contact varchar,
    campaign number(38,
    0),
    y varchar,
    id number(38,
    0),
    job varchar,
    day number(38,
    0),
    age number(38,
    0),
    pdays number(38,
    0),
    c_default varchar,
    _fivetran_deleted boolean,
    _fivetran_synced timestamp_tz
);

create or replace table risk_assess_customers (
    ctid_fivetran_id varchar,
    credit_score number(38,
    0),
    is_homeowner varchar,
    num_recent_inquiries number(38,
    0),
    num_delinquencies_last_2_years number(38,
    0),
    credit_score_range varchar,
    num_credit_accounts number(38,
    0),
    employment_sector varchar,
    income_bracket varchar,
    segment varchar,
    years_of_credit_history number(38,
    0),
    has_previous_bankruptcy varchar,
    education_level varchar,
    customer_name varchar,
    customer_id varchar,
    debt_to_income_ratio number(2,
    2),
    annual_income number(9,
    2),
    _fivetran_deleted boolean,
    _fivetran_synced timestamp_tz
);

create or replace table risk_assess_financial_institutions (
    ctid_fivetran_id varchar,
    avg_customer_lifetime_years number(3,
    1),
    institution_type varchar,
    risk_appetite number(2,
    2),
    years_in_operation number(38,
    0),
    assets_under_management_billions number(5,
    2),
    institution_size varchar,
    institution_name varchar,
    institution_id varchar,
    customer_base_millions number(3,
    2),
    fraud_loss_percentage number(3,
    3),
    default_rate_percentage number(3,
    2),
    digital_maturity_score number(38,
    0),
    regulatory_rating number(38,
    0),
    region varchar,
    primary_risk_model varchar,
    _fivetran_deleted boolean,
    _fivetran_synced timestamp_tz
);

create or replace table risk_assess_monthly_assessments (
    ctid_fivetran_id varchar,
    date varchar,
    current_risk_score number(3,
    3),
    is_anomaly varchar,
    risk_change_from_previous varchar,
    year number(38,
    0),
    transaction_count number(38,
    0),
    fraud_probability number(3,
    3),
    assessment_id number(38,
    0),
    monthly_transaction_volume number(9,
    2),
    approval_confidence number(2,
    2),
    institution_id varchar,
    risk_level varchar,
    month number(38,
    0),
    anomaly_type varchar,
    customer_id varchar,
    primary_explanation_factors varchar,
    approval_recommendation varchar,
    _fivetran_deleted boolean,
    _fivetran_synced timestamp_tz
);

create or replace table risk_assess_performance_metrics (
    ctid_fivetran_id varchar,
    customer_value_score number(38,
    0),
    avg_risk_score number(3,
    3),
    most_common_recommendation varchar,
    total_transaction_volume number(10,
    2),
    risk_assessment_accuracy number(4,
    1),
    transaction_volatility number(2,
    2),
    total_exposure number(10,
    2),
    avg_monthly_transaction_volume number(8,
    2),
    institution_id varchar,
    performance_id number(38,
    0),
    risk_trend varchar,
    product_type varchar,
    risk_score_volatility number(3,
    3),
    anomaly_percentage number(3,
    1),
    customer_value_category varchar,
    optimization_opportunity varchar,
    risk_adjusted_return number(4,
    3),
    risk_trend_percentage number(4,
    1),
    optimization_priority varchar,
    customer_id varchar,
    avg_fraud_probability number(3,
    3),
    approval_percentage number(4,
    1),
    _fivetran_deleted boolean,
    _fivetran_synced timestamp_tz
);

create or replace table risk_assess_risk_profiles (
    ctid_fivetran_id varchar,
    risk_factor_weights varchar,
    total_exposure number(10,
    2),
    recent_transaction_volatility number(3,
    2),
    risk_pattern varchar,
    collateral_quality_score varchar,
    products_held number(38,
    0),
    institution_id varchar,
    risk_profile_id number(38,
    0),
    base_risk_score number(2,
    2),
    primary_risk_factors varchar,
    product_type varchar,
    relationship_length_months number(38,
    0),
    liquidity_ratio varchar,
    customer_id varchar,
    repayment_history_score number(38,
    0),
    projected_cash_flow_rating varchar,
    _fivetran_deleted boolean,
    _fivetran_synced timestamp_tz
);

-- 4. Load ------------------------------------------------------------------------------
copy into fpr_records
    from @larkspur_repo/branches/main/data/financial_services/fpr_records.csv.gz
    file_format = (format_name = 'larkspur_csv');

copy into loan
    from @larkspur_repo/branches/main/data/financial_services/loan.csv.gz
    file_format = (format_name = 'larkspur_csv');

copy into predict_term_deposit
    from @larkspur_repo/branches/main/data/financial_services/predict_term_deposit.csv.gz
    file_format = (format_name = 'larkspur_csv');

copy into risk_assess_customers
    from @larkspur_repo/branches/main/data/financial_services/risk_assess_customers.csv.gz
    file_format = (format_name = 'larkspur_csv');

copy into risk_assess_financial_institutions
    from @larkspur_repo/branches/main/data/financial_services/risk_assess_financial_institutions.csv.gz
    file_format = (format_name = 'larkspur_csv');

copy into risk_assess_monthly_assessments
    from @larkspur_repo/branches/main/data/financial_services/risk_assess_monthly_assessments.csv.gz
    file_format = (format_name = 'larkspur_csv');

copy into risk_assess_performance_metrics
    from @larkspur_repo/branches/main/data/financial_services/risk_assess_performance_metrics.csv.gz
    file_format = (format_name = 'larkspur_csv');

copy into risk_assess_risk_profiles
    from @larkspur_repo/branches/main/data/financial_services/risk_assess_risk_profiles.csv.gz
    file_format = (format_name = 'larkspur_csv');

-- 5. Check: expect 8 tables, 198,723 rows in total -------------------------------------
select 'fpr_records' as table_name, count(*) as row_count from fpr_records
union all select 'loan', count(*) from loan
union all select 'predict_term_deposit', count(*) from predict_term_deposit
union all select 'risk_assess_customers', count(*) from risk_assess_customers
union all select 'risk_assess_financial_institutions', count(*) from risk_assess_financial_institutions
union all select 'risk_assess_monthly_assessments', count(*) from risk_assess_monthly_assessments
union all select 'risk_assess_performance_metrics', count(*) from risk_assess_performance_metrics
union all select 'risk_assess_risk_profiles', count(*) from risk_assess_risk_profiles
order by 1;
