-- One row per customer segment x credit score band on the risk platform: who the
-- customers are and how risky they look today. No names: aggregates only.

select
    customer_segment,
    credit_score_range,
    count(*)                                                    as customers,
    cast(avg(annual_income) as number(14, 2))                   as avg_annual_income,
    sum(total_exposure)                                         as total_exposure,
    cast(avg(avg_latest_risk_score) as number(5, 3))            as avg_latest_risk_score,
    count_if(high_risk_relationship_count > 0)                  as customers_with_high_risk_relationship

from {{ ref('platform', 'dim_customers') }}
group by 1, 2
