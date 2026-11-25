{{ config(materialized='semantic_view', schema='semantic', static_analysis='off') }}
-- Snowflake semantic view over the credit-risk platform marts, for Cortex Analyst,
-- Snowflake Intelligence and Cortex Code. Metrics mirror the dbt Semantic Layer
-- definitions (approval_rate, high_risk_rate, high_risk_exposure_share...) so a
-- Snowflake agent and a dbt Semantic Layer query return the same number.

tables (
    assessments as {{ ref('fct_risk_assessments') }}
        primary key (assessment_id)
        comment = 'One row per monthly risk assessment of a customer-institution relationship (36 periods of 30 days).',
    relationships as {{ ref('dim_credit_relationships') }}
        primary key (relationship_id)
        comment = 'One row per customer-institution credit relationship, with exposure and latest risk position.',
    institutions as {{ ref('dim_institutions') }}
        primary key (institution_id)
        comment = 'One row per financial institution on the shared risk platform. Names repeat: always show the id too.'
)

relationships (
    assessment_relationship as assessments (relationship_id) references relationships,
    relationship_institution as relationships (institution_id) references institutions
)

facts (
    assessments.risk_score_value as assessments.risk_score
        comment = 'Model risk score, 0 to 1.',
    assessments.fraud_probability_value as assessments.fraud_probability,
    relationships.exposure_usd as relationships.total_exposure
        comment = 'Current exposure of the relationship, USD. A balance, never summed across periods.'
)

dimensions (
    assessments.assessment_date as assessments.assessment_date
        comment = 'Assessment date. Periods are 30 days, not calendar months: trend by period_number.',
    assessments.period_number as assessments.period_number
        with synonyms = ('period', 'assessment period')
        comment = 'Assessment period, 1 to 36. Use this for risk trends.',
    assessments.risk_level as assessments.risk_level
        comment = 'Low, Medium, High or Very High.',
    assessments.approval_recommendation as assessments.approval_recommendation
        comment = 'Source recommendation. Only Approve and Approve with Conditions count as approved.',
    assessments.anomaly_type as assessments.anomaly_type,
    assessments.primary_explanation_factors as assessments.primary_explanation_factors,
    relationships.relationship_id as relationships.relationship_id,
    relationships.product_type as relationships.product_type
        with synonyms = ('product', 'credit product'),
    relationships.risk_pattern as relationships.risk_pattern,
    relationships.risk_trend as relationships.risk_trend,
    relationships.latest_risk_level as relationships.latest_risk_level
        comment = 'Risk level at the latest assessment period.',
    relationships.customer_value_category as relationships.customer_value_category,
    relationships.optimization_priority as relationships.optimization_priority,
    relationships.is_secured_product as relationships.is_secured_product,
    institutions.institution_id as institutions.institution_id,
    institutions.institution_name as institutions.institution_name
        with synonyms = ('bank', 'lender', 'institution'),
    institutions.institution_type as institutions.institution_type,
    institutions.institution_size as institutions.institution_size,
    institutions.region as institutions.region
)

metrics (
    assessments.assessment_count as count(assessments.assessment_id),
    assessments.approval_rate as count_if(assessments.is_approved) / nullif(count(assessments.assessment_id), 0)
        with synonyms = ('approval percentage')
        comment = 'Governed definition: Approve or Approve with Conditions over all assessments. Not any_approval_rate.',
    assessments.any_approval_rate as count_if(assessments.is_any_approval) / nullif(count(assessments.assessment_id), 0)
        comment = 'Broader reading that includes Approve with Strict Conditions. About 13 points above approval_rate.',
    assessments.denial_rate as count_if(assessments.is_denied) / nullif(count(assessments.assessment_id), 0),
    assessments.high_risk_rate as count_if(assessments.is_high_risk) / nullif(count(assessments.assessment_id), 0)
        comment = 'Share of assessments rated High or Very High.',
    assessments.anomaly_rate as count_if(assessments.is_anomaly) / nullif(count(assessments.assessment_id), 0),
    assessments.fraud_alert_count as count_if(assessments.is_fraud_alert),
    assessments.avg_risk_score as avg(assessments.risk_score_value),
    assessments.avg_fraud_probability as avg(assessments.fraud_probability_value),
    relationships.relationship_count as count(relationships.relationship_id),
    relationships.total_exposure_usd as sum(relationships.exposure_usd)
        with synonyms = ('exposure', 'book size')
        comment = 'Current exposure, USD.',
    relationships.high_risk_exposure_usd as sum(iff(relationships.is_latest_high_risk, relationships.exposure_usd, 0)),
    relationships.high_risk_exposure_share as sum(iff(relationships.is_latest_high_risk, relationships.exposure_usd, 0)) / nullif(sum(relationships.exposure_usd), 0)
        comment = 'Share of exposure in relationships whose latest risk level is High or Very High.'
)

comment = 'Larkspur Financial credit-risk platform. Built and tested by dbt (project platform, public marts under enforced contracts).'
