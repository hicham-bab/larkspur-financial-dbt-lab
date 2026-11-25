{#
  Training set for a term-deposit propensity model. One row per contacted client.

  LEAKAGE GUARD: call_duration_seconds is excluded. It is only known once the call
  is over, and it nearly decides the label on its own (0.2% conversion under 60
  seconds, 48% over 600). A model trained on it is useless for choosing whom to call.
#}

select
    contact_id,
    age,
    age_band,
    job,
    marital_status,
    education,
    has_credit_in_default,
    average_yearly_balance_eur,
    has_housing_loan,
    has_personal_loan,
    contact_channel,
    contacts_this_campaign,
    contacts_before_this_campaign,
    days_since_previous_campaign_contact,
    was_previously_contacted,
    previous_campaign_outcome,
    subscribed                                          as label_subscribed

from {{ ref('platform', 'fct_campaign_contacts') }}
