-- Day-grain time spine for this project's own Semantic Layer. Each dbt project that
-- defines metrics needs one; the platform's dim_date is not visible to MetricFlow here.

{{ config(materialized = 'table') }}

select dateadd(day, seq4(), cast('2007-01-01' as date)) as date_day
from table(generator(rowcount => 7305))
