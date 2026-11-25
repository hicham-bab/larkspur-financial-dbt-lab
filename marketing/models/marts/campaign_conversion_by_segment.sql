-- One row per (segment_type, segment_value): contacts, subscriptions and conversion
-- for the term-deposit campaign. Long format so one table answers "which age band /
-- job / channel / prior outcome converts best" without a pivot. No time axis exists.

with contacts as (

    select * from {{ ref('platform', 'fct_campaign_contacts') }}

),

long as (

    select 'age_band' as segment_type, age_band as segment_value, subscribed from contacts
    union all
    select 'job', coalesce(job, 'unknown'), subscribed from contacts
    union all
    select 'education', coalesce(education, 'unknown'), subscribed from contacts
    union all
    select 'contact_channel', coalesce(contact_channel, 'unknown'), subscribed from contacts
    union all
    select 'previous_campaign_outcome', coalesce(previous_campaign_outcome, 'not previously contacted'), subscribed from contacts

)

select
    segment_type,
    segment_value,
    count(*)                                             as contacts,
    count_if(subscribed)                                 as subscriptions,
    cast(avg(iff(subscribed, 1, 0)) as number(6, 4))     as conversion_rate,
    cast(avg(iff(subscribed, 1, 0)) / (select avg(iff(subscribed, 1, 0)) from contacts) as number(6, 2)) as lift_vs_overall

from long
group by 1, 2
