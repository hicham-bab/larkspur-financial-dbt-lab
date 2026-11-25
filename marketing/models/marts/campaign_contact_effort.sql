-- Diminishing returns of calling the same client again within one campaign.

with contacts as (

    select
        case
            when contacts_this_campaign >= 10 then '10+'
            else cast(contacts_this_campaign as varchar)
        end                                     as contact_attempts,
        least(contacts_this_campaign, 10)       as sort_order,
        subscribed
    from {{ ref('platform', 'fct_campaign_contacts') }}

)

select
    contact_attempts,
    min(sort_order)                                     as sort_order,
    count(*)                                            as contacts,
    count_if(subscribed)                                as subscriptions,
    cast(avg(iff(subscribed, 1, 0)) as number(6, 4))    as conversion_rate

from contacts
group by 1
