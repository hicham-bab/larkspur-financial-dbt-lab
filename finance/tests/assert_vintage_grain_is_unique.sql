select issue_year, grade
from {{ ref('fct_loan_vintage_performance') }}
group by 1, 2
having count(*) > 1
