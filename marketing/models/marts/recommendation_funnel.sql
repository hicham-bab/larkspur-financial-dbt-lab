-- One row per recommended product: how recommendations progress through status.

select
    recommended_product,
    count(*)                                                    as recommendations,
    count_if(recommendation_status = 'Pending')                 as pending,
    count_if(recommendation_status = 'In Progress')             as in_progress,
    count_if(recommendation_status = 'Approved')                as approved,
    count_if(recommendation_status = 'Accepted')                as accepted,
    count_if(recommendation_status = 'Declined')                as declined,
    count_if(recommendation_status = 'Rejected')                as rejected,
    cast(avg(iff(is_accepted, 1, 0)) as number(6, 4))           as acceptance_rate,
    cast(avg(recommendation_score) as number(6, 3))             as avg_recommendation_score

from {{ ref('platform', 'fct_product_recommendations') }}
group by 1
