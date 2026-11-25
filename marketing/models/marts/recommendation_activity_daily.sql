-- One row per recommendation date x recommended product. Gives the recommendation log a
-- time axis, so marketing can own its recommendation metrics in its own Semantic Layer.

select
    recommendation_date,
    recommended_product,
    count(*)                                                    as recommendations,
    count_if(is_accepted)                                       as accepted_recommendations,
    count_if(recommendation_status in ('Declined', 'Rejected')) as lost_recommendations,
    sum(recommendation_score)                                   as recommendation_score_sum

from {{ ref('platform', 'fct_product_recommendations') }}
group by 1, 2
