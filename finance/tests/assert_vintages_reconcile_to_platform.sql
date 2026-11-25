-- The consumer's totals must equal the producer's: the Mesh contract in one query.
select 1
from (select sum(loans) as loans, sum(charged_off_loans) as charged_off from {{ ref('fct_loan_vintage_performance') }}) as finance
cross join (select count(*) as loans, count_if(is_charged_off) as charged_off from {{ ref('platform', 'fct_loans') }}) as platform
where finance.loans <> platform.loans
   or finance.charged_off <> platform.charged_off
