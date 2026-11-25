-- One row per issue year x grade. The lending book's vintage curve: how much was
-- written, how much is known (matured), and how much was lost.

with loans as (

    select * from {{ ref('platform', 'fct_loans') }}

)

select
    issue_year,
    -- First day of the vintage year: the time axis for the Semantic Layer (year grain).
    cast(date_from_parts(issue_year, 1, 1) as date)                 as vintage_start_date,
    grade,
    count(*)                                                        as loans,
    sum(funded_amount)                                              as funded_amount,
    count_if(is_matured)                                            as matured_loans,
    count_if(is_charged_off)                                        as charged_off_loans,
    -- Matured loans only in the denominator: a 'Current' loan has not defaulted YET.
    cast(count_if(is_charged_off) / nullif(count_if(is_matured), 0) as number(6, 4))       as charge_off_rate,
    sum(net_principal_loss)                                         as net_principal_loss,
    cast(sum(net_principal_loss) / nullif(sum(iff(is_matured, funded_amount, 0)), 0) as number(6, 4)) as net_loss_rate,
    cast(avg(interest_rate_pct) as number(6, 2))                    as avg_interest_rate_pct,
    sum(total_received_interest)                                    as interest_received

from loans
group by 1, 2, 3
