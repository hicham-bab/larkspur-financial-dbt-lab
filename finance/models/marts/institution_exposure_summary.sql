-- One row per member institution x product. Where the platform's exposure sits and
-- how much of it is in relationships that are high risk today.

with relationships as (

    select * from {{ ref('platform', 'dim_credit_relationships') }}

),

institutions as (

    select * from {{ ref('platform', 'dim_institutions') }}

)

select
    relationships.institution_id,
    institutions.institution_name,
    institutions.institution_type,
    institutions.region,
    relationships.product_type,
    count(*)                                                            as relationships,
    sum(relationships.total_exposure)                                   as total_exposure,
    sum(iff(relationships.is_latest_high_risk, relationships.total_exposure, 0)) as high_risk_exposure,
    cast(sum(iff(relationships.is_latest_high_risk, relationships.total_exposure, 0))
        / nullif(sum(relationships.total_exposure), 0) as number(6, 4))  as high_risk_exposure_share,
    -- exposure-weighted, so one large relationship is not outvoted by many small ones
    cast(sum(relationships.risk_adjusted_return * relationships.total_exposure)
        / nullif(sum(relationships.total_exposure), 0) as number(8, 3))  as exposure_weighted_risk_adjusted_return,
    max(relationships.as_of_date)                                       as as_of_date

from relationships
inner join institutions
    on relationships.institution_id = institutions.institution_id
group by 1, 2, 3, 4, 5
