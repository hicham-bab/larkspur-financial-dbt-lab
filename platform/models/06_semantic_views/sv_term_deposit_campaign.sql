{{ config(materialized='semantic_view', schema='semantic', static_analysis='off') }}
-- Snowflake semantic view over the term-deposit marketing campaign.
-- call_duration_seconds is deliberately left out: it is only known after the call, so
-- using it to choose who to call leaks the outcome (see context/data_caveats.md).

tables (
    contacts as {{ ref('fct_campaign_contacts') }}
        primary key (contact_id)
        comment = 'One row per customer contacted in the term-deposit campaign (45K). Balances in EUR.'
)

facts (
    contacts.balance_eur as contacts.average_yearly_balance_eur,
    contacts.contacts_in_campaign as contacts.contacts_this_campaign
)

dimensions (
    contacts.age_band as contacts.age_band,
    contacts.job as contacts.job
        with synonyms = ('occupation'),
    contacts.marital_status as contacts.marital_status,
    contacts.education as contacts.education,
    contacts.contact_channel as contacts.contact_channel,
    contacts.last_contact_month as contacts.last_contact_month,
    contacts.previous_campaign_outcome as contacts.previous_campaign_outcome,
    contacts.was_previously_contacted as contacts.was_previously_contacted,
    contacts.has_housing_loan as contacts.has_housing_loan,
    contacts.has_personal_loan as contacts.has_personal_loan,
    contacts.has_credit_in_default as contacts.has_credit_in_default,
    contacts.subscribed as contacts.subscribed
)

metrics (
    contacts.contact_count as count(contacts.contact_id),
    contacts.subscriber_count as count_if(contacts.subscribed),
    contacts.subscription_rate as count_if(contacts.subscribed) / nullif(count(contacts.contact_id), 0)
        with synonyms = ('conversion rate', 'take-up rate'),
    contacts.avg_contacts_per_customer as avg(contacts.contacts_in_campaign),
    contacts.avg_balance_eur as avg(contacts.balance_eur)
)

comment = 'Larkspur Financial term-deposit campaign. Built and tested by dbt (fct_campaign_contacts, enforced contract).'
