-- One row per credit relationship: how its risk moved over the 36 periods.
-- Feature input for early-warning and fraud models.

with assessments as (

    select * from {{ ref('platform', 'fct_risk_assessments') }}

),

trajectory as (

    select
        relationship_id,
        min_by(risk_score, period_number)                               as first_risk_score,
        max_by(risk_score, period_number)                               as latest_risk_score,
        cast(regr_slope(risk_score, period_number) as number(8, 5))     as risk_score_slope_per_period,
        cast(stddev(risk_score) as number(6, 4))                        as risk_score_stddev,
        count_if(is_high_risk)                                          as high_risk_periods,
        count_if(is_denied)                                             as denied_periods,
        count_if(is_anomaly)                                            as anomaly_periods,
        count_if(is_fraud_alert)                                        as fraud_alert_periods,
        max(fraud_probability)                                          as max_fraud_probability,
        -- risk in the last 6 periods vs the first 6
        cast(avg(iff(period_number > 30, risk_score, null))
           - avg(iff(period_number <= 6, risk_score, null)) as number(6, 3)) as risk_score_change_first_to_last_6

    from assessments
    group by 1

)

select
    relationships.relationship_id,
    relationships.customer_id,
    relationships.institution_id,
    relationships.product_type,
    relationships.total_exposure,
    relationships.risk_pattern,
    trajectory.first_risk_score,
    trajectory.latest_risk_score,
    trajectory.risk_score_slope_per_period,
    trajectory.risk_score_stddev,
    trajectory.risk_score_change_first_to_last_6,
    trajectory.high_risk_periods,
    trajectory.denied_periods,
    trajectory.anomaly_periods,
    trajectory.fraud_alert_periods,
    trajectory.max_fraud_probability

from {{ ref('platform', 'dim_credit_relationships') }} as relationships
inner join trajectory
    on relationships.relationship_id = trajectory.relationship_id
