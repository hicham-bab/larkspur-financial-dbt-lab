-- One row per assessment period (1..36). The risk book over time, on the platform's
-- own 30-day cadence. Do not relabel these rows as calendar months.

select
    period_number,
    assessment_date,
    count(*)                                                    as assessments,
    cast(avg(risk_score) as number(5, 3))                       as avg_risk_score,
    cast(avg(iff(is_high_risk, 1, 0)) as number(6, 4))          as high_risk_rate,
    cast(avg(iff(is_approved, 1, 0)) as number(6, 4))           as approval_rate,
    cast(avg(iff(is_denied, 1, 0)) as number(6, 4))             as denial_rate,
    cast(avg(iff(is_anomaly, 1, 0)) as number(6, 4))            as anomaly_rate,
    count_if(is_fraud_alert)                                    as fraud_alerts,
    sum(transaction_volume)                                     as transaction_volume

from {{ ref('platform', 'fct_risk_assessments') }}
group by 1, 2
