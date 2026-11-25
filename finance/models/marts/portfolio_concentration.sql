-- One row per customer segment x product: share of total platform exposure.
-- Concentration is what a credit committee asks about first.

with relationships as (

    select
        relationships.*,
        customers.customer_segment
    from {{ ref('platform', 'dim_credit_relationships') }} as relationships
    inner join {{ ref('platform', 'dim_customers') }} as customers
        on relationships.customer_id = customers.customer_id

)

select
    customer_segment,
    product_type,
    count(*)                                                                as relationships,
    sum(total_exposure)                                                     as total_exposure,
    cast(sum(total_exposure) / sum(sum(total_exposure)) over () as number(6, 4)) as share_of_total_exposure,
    cast(avg(latest_risk_score) as number(5, 3))                            as avg_latest_risk_score

from relationships
group by 1, 2
