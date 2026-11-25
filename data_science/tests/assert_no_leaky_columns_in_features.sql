-- Fails if anyone adds an outcome-bearing column back into a training set.
-- depends_on: {{ ref('loan_default_features') }}
-- depends_on: {{ ref('term_deposit_propensity_features') }}

{% set guarded = {
    'loan_default_features': ['total_payment', 'total_received_principal', 'total_received_interest',
                              'recoveries', 'collection_recovery_fee', 'last_payment_date',
                              'outstanding_principal', 'net_principal_loss', 'loan_status'],
    'term_deposit_propensity_features': ['call_duration_seconds'],
} %}

{% set leaks = [] %}
{% if execute %}
    {% for model_name, banned in guarded.items() %}
        {% for column in adapter.get_columns_in_relation(ref(model_name)) %}
            {% if column.name | lower in banned %}
                {% do leaks.append(model_name ~ '.' ~ (column.name | lower)) %}
            {% endif %}
        {% endfor %}
    {% endfor %}
{% endif %}

{% if leaks %}
    {% for leak in leaks %}
select '{{ leak }}' as leaked_column
        {% if not loop.last %}union all{% endif %}
    {% endfor %}
{% else %}
select cast(null as varchar) as leaked_column
where false
{% endif %}
