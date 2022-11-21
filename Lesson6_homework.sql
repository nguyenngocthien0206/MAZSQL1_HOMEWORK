-- COHORT ANALYSIS METHOD
-- 1. Retention
-- 1.1. Basic Retention Curve:
/* Task:
A. As you know that 'Telco Card' is the most product in the Telco group (accounting for more
than 99% of the total). You want to evaluate the quality of user acquisition in Jan 2019 by the
retention metric. First, you need to know how many users are retained in each subsequent
month from the first month (Jan 2019) they pay the successful transaction (only get data of
2019).*/

WITH query_table AS (
SELECT customer_id, transaction_id, transaction_time
    , MIN(transaction_time) OVER( PARTITION BY customer_id) AS first_time
    , DATEDIFF(month, MIN(transaction_time) OVER( PARTITION BY customer_id), transaction_time) AS subsequent_month
FROM fact_transaction_2019 fact 
JOIN dim_scenario sce ON fact.scenario_id = sce.scenario_id
WHERE sub_category = 'Telco Card' AND status_id = 1
)
SELECT subsequent_month
    , COUNT( DISTINCT customer_id) AS retained_users
FROM query_table
WHERE MONTH(first_time) = 1
GROUP BY subsequent_month
ORDER BY subsequent_month 

/* B. You realize that the number of retained customers has decreased over time. Let’s calculate
retention = number of retained customers / total users of the first month.*/
WITH query_table AS (
SELECT customer_id, transaction_id, transaction_time
    , MIN(transaction_time) OVER( PARTITION BY customer_id) AS first_time
    , DATEDIFF(month, MIN(transaction_time) OVER( PARTITION BY customer_id), transaction_time) AS subsequent_month
FROM fact_transaction_2019 fact 
JOIN dim_scenario sce ON fact.scenario_id = sce.scenario_id
WHERE sub_category = 'Telco Card' AND status_id = 1
)
, retained_user AS (
SELECT subsequent_month
    , COUNT( DISTINCT customer_id) AS retained_users
FROM query_table
WHERE MONTH(first_time) = 1
GROUP BY subsequent_month
-- ORDER BY subsequent_month
)
SELECT *
    , FIRST_VALUE(retained_users) OVER( ORDER BY subsequent_month ASC) AS original_users
    , FORMAT(1.0*retained_users/FIRST_VALUE(retained_users) OVER( ORDER BY subsequent_month ASC), 'p') AS pct_retained_users
FROM retained_user

-- 1.2. Cohorts Derived from the Time Series Itself
/* Task: Expend your previous query to calculate retention for multi attributes from the acquisition
month (from Jan to December).*/
-- way 1:
WITH query_table AS
(
    SELECT ft.transaction_id, ft.customer_id, ft.transaction_time
    FROM dbo.fact_transaction_2019 ft
    JOIN dbo.dim_scenario sc ON sc.scenario_id = ft.scenario_id
    WHERE ft.status_id = 1 AND sc.sub_category = 'Telco Card')
, user_first_month AS
(
    SELECT customer_id
        , MIN(MONTH(transaction_time)) AS first_month
    FROM query_table
    GROUP BY customer_id)
, new_user_by_month AS
(
    SELECT first_month
        , COUNT(customer_id) AS new_users
    FROM user_first_month
    GROUP BY first_month)
, user_retention_month AS
(
    SELECT customer_id
        , MONTH(transaction_time) AS retention_month
    FROM query_table
    GROUP BY customer_id, MONTH(transaction_time))
, summary_table AS
(
    SELECT ufm.first_month AS acquisition_month
        , (urm.retention_month-ufm.first_month) AS subsequent_month
        , COUNT(urm.customer_id) AS retained_users
    FROM user_retention_month urm
    LEFT JOIN user_first_month ufm ON ufm.customer_id = urm.customer_id
    GROUP BY (urm.retention_month-ufm.first_month), ufm.first_month)
SELECT acquisition_month
	, subsequent_month
    , retained_users
    , FIRST_VALUE(retained_users) OVER(ORDER BY acquisition_month) AS original_users
    , FORMAT(1.0*retained_users/(FIRST_VALUE(retained_users) OVER(ORDER BY acquisition_month)),'p')  AS pct_retained
FROM summary_table

-- way 2:
WITH period_table AS (
SELECT customer_id, transaction_id, transaction_time
    , MIN(transaction_time) OVER( PARTITION BY customer_id) AS first_time
    , DATEDIFF(month, MIN(transaction_time) OVER( PARTITION BY customer_id), transaction_time) AS subsequent_month
FROM fact_transaction_2019 fact 
JOIN dim_scenario sce ON fact.scenario_id = sce.scenario_id
WHERE sub_category = 'Telco Card' AND status_id = 1
)
, retained_user AS (
SELECT MONTH(first_time) AS acquisition_month
    , subsequent_month
    , COUNT( DISTINCT customer_id) AS retained_users
FROM period_table
GROUP BY MONTH(first_time) , subsequent_month
-- ORDER BY acquisition_month, subsequent_month
)
SELECT *
    , FIRST_VALUE(retained_users) OVER( PARTITION BY acquisition_month ORDER BY subsequent_month ASC) AS original_users
    , FORMAT(1.0*retained_users/FIRST_VALUE(retained_users) OVER(PARTITION BY acquisition_month ORDER BY subsequent_month ASC), 'p') AS pct_retained_users
FROM retained_user

-- Then modify the result as the following table:
-- way 1:
	WITH query_table AS
	(
		SELECT ft.transaction_id, ft.customer_id, ft.transaction_time
		FROM dbo.fact_transaction_2019 ft
		JOIN dbo.dim_scenario sc ON sc.scenario_id = ft.scenario_id
		WHERE ft.status_id = 1 AND sc.sub_category = 'Telco Card')
	, user_first_month AS
	(
		SELECT customer_id
			, MIN(MONTH(transaction_time)) AS first_month
		FROM query_table
		GROUP BY customer_id)
	, new_user_by_month AS
	(
		SELECT first_month
			, COUNT(customer_id) AS new_users
		FROM user_first_month
		GROUP BY first_month)
	, user_retention_month AS
	(
		SELECT customer_id
			, MONTH(transaction_time) AS retention_month
		FROM query_table
		GROUP BY customer_id, MONTH(transaction_time))
	, summary_table AS
	(
		SELECT ufm.first_month AS acquisition_month
			, (urm.retention_month-ufm.first_month) AS subsequent_month
			, COUNT(urm.customer_id) AS retained_users
		FROM user_retention_month urm
		LEFT JOIN user_first_month ufm ON ufm.customer_id = urm.customer_id
		GROUP BY (urm.retention_month-ufm.first_month), ufm.first_month)
	, pct_count AS
	(
		SELECT acquisition_month
			, subsequent_month
			, retained_users
			, FIRST_VALUE(retained_users) OVER(PARTITION BY acquisition_month ORDER BY subsequent_month) AS original_users
			, FORMAT(1.0*retained_users/(FIRST_VALUE(retained_users) OVER(PARTITION BY acquisition_month ORDER BY subsequent_month)),'p')  AS pct_retained
		FROM summary_table)
, original_users_month AS
(
	SELECT DISTINCT acquisition_month
		, FIRST_VALUE(retained_users) OVER(PARTITION BY acquisition_month ORDER BY subsequent_month) AS original_users
	FROM summary_table)
, pct_retained_0 AS (SELECT acquisition_month, pct_retained FROM pct_count WHERE subsequent_month = 0)
, pct_retained_1 AS (SELECT acquisition_month, pct_retained FROM pct_count WHERE subsequent_month = 1)
, pct_retained_2 AS (SELECT acquisition_month, pct_retained FROM pct_count WHERE subsequent_month = 2)
, pct_retained_3 AS (SELECT acquisition_month, pct_retained FROM pct_count WHERE subsequent_month = 3)
, pct_retained_4 AS (SELECT acquisition_month, pct_retained FROM pct_count WHERE subsequent_month = 4)
, pct_retained_5 AS (SELECT acquisition_month, pct_retained FROM pct_count WHERE subsequent_month = 5)
, pct_retained_6 AS (SELECT acquisition_month, pct_retained FROM pct_count WHERE subsequent_month = 6)
, pct_retained_7 AS (SELECT acquisition_month, pct_retained FROM pct_count WHERE subsequent_month = 7)
, pct_retained_8 AS (SELECT acquisition_month, pct_retained FROM pct_count WHERE subsequent_month = 8)
, pct_retained_9 AS (SELECT acquisition_month, pct_retained FROM pct_count WHERE subsequent_month = 9)
, pct_retained_10 AS (SELECT acquisition_month, pct_retained FROM pct_count WHERE subsequent_month = 10)
, pct_retained_11 AS (SELECT acquisition_month, pct_retained FROM pct_count WHERE subsequent_month = 11)
SELECT oum.acquisition_month
	, oum.original_users
	, pr0.pct_retained AS [0]
	, pr1.pct_retained AS [1]
	, pr2.pct_retained AS [2]
	, pr3.pct_retained AS [3]
	, pr4.pct_retained AS [4]
	, pr5.pct_retained AS [5]
	, pr6.pct_retained AS [6]
	, pr7.pct_retained AS [7]
	, pr8.pct_retained AS [8]
	, pr9.pct_retained AS [9]
	, pr10.pct_retained AS [10]
	, pr11.pct_retained AS [11]
FROM original_users_month oum
LEFT JOIN pct_retained_0 pr0 ON pr0.acquisition_month = oum.acquisition_month
LEFT JOIN pct_retained_1 pr1 ON pr1.acquisition_month = oum.acquisition_month
LEFT JOIN pct_retained_2 pr2 ON pr2.acquisition_month = oum.acquisition_month
LEFT JOIN pct_retained_3 pr3 ON pr3.acquisition_month = oum.acquisition_month
LEFT JOIN pct_retained_4 pr4 ON pr4.acquisition_month = oum.acquisition_month
LEFT JOIN pct_retained_5 pr5 ON pr5.acquisition_month = oum.acquisition_month
LEFT JOIN pct_retained_6 pr6 ON pr6.acquisition_month = oum.acquisition_month
LEFT JOIN pct_retained_7 pr7 ON pr7.acquisition_month = oum.acquisition_month
LEFT JOIN pct_retained_8 pr8 ON pr8.acquisition_month = oum.acquisition_month
LEFT JOIN pct_retained_9 pr9 ON pr9.acquisition_month = oum.acquisition_month
LEFT JOIN pct_retained_10 pr10 ON pr10.acquisition_month = oum.acquisition_month
LEFT JOIN pct_retained_11 pr11 ON pr11.acquisition_month = oum.acquisition_month

-- way 2:
WITH period_table AS (
SELECT customer_id, transaction_id, transaction_time
    , MIN(transaction_time) OVER( PARTITION BY customer_id) AS first_time
    , DATEDIFF(month, MIN(transaction_time) OVER( PARTITION BY customer_id), transaction_time) AS subsequent_month
FROM fact_transaction_2019 fact 
JOIN dim_scenario sce ON fact.scenario_id = sce.scenario_id
WHERE sub_category = 'Telco Card' AND status_id = 1
)
, retained_user AS (
SELECT MONTH(first_time) AS acquisition_month
    , subsequent_month
    , COUNT( DISTINCT customer_id) AS retained_users
FROM period_table
GROUP BY MONTH(first_time) , subsequent_month
-- ORDER BY acquisition_month, subsequent_month
)
, acquisition_table AS (
SELECT *
    , FIRST_VALUE(retained_users) OVER( PARTITION BY acquisition_month ORDER BY subsequent_month ASC) AS original_users
    , FORMAT(1.0*retained_users/FIRST_VALUE(retained_users) OVER(PARTITION BY acquisition_month ORDER BY subsequent_month ASC), 'p') AS pct_retained_users
FROM retained_user)

SELECT acquisition_month, original_users
    , "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"
FROM (
    SELECT acquisition_month, original_users, subsequent_month, pct_retained_users 
    FROM acquisition_table
) AS table_source
PIVOT (
    MIN(pct_retained_users)
    FOR subsequent_month IN ("0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11")
) AS pivot_table

-- 2. USER SEGMENTATION
/* 2.1. The first step in building an RFM model is to assign Recency, Frequency and Monetary values to
each customer. Let’s calculate these metrics for all successful paying customer of ‘Telco Card’ in
2019 and 2020:*/
WITH fact_table AS (
    SELECT fact_19.*
    FROM fact_transaction_2019 fact_19 
    JOIN dim_scenario sce ON fact_19.scenario_id = sce.scenario_id
    WHERE sub_category = 'Telco Card' AND status_id = 1
UNION
    SELECT fact_20.*
    FROM fact_transaction_2020 fact_20 
    JOIN dim_scenario sce ON fact_20.scenario_id = sce.scenario_id
    WHERE sub_category = 'Telco Card' AND status_id = 1
)
, rfm_table AS (
SELECT customer_id
    , DATEDIFF(day, MAX (transaction_time), '2020-12-31') AS recency 
    , COUNT( DISTINCT FORMAT(transaction_time, 'yy.mm.dd')) AS frequency
    , SUM (charged_amount) AS monetary
FROM fact_table
GROUP BY customer_id
)
, rfm_rank AS (
SELECT *
    , PERCENT_RANK() OVER( ORDER BY recency ASC) AS r_rank
    , PERCENT_RANK() OVER( ORDER BY frequency DESC) AS f_rank
    , PERCENT_RANK() OVER( ORDER BY monetary DESC) AS m_rank
FROM rfm_table
)
, rfm_score AS (
SELECT *
    , CASE WHEN r_rank > 0.75 THEN 4
        WHEN r_rank > 0.5 THEN 3
        WHEN r_rank > 0.25 THEN 2
        ELSE 1 END AS r_score
    , CASE WHEN f_rank > 0.75 THEN 4
        WHEN f_rank > 0.5 THEN 3
        WHEN f_rank > 0.25 THEN 2
        ELSE 1 END AS f_score
    , CASE WHEN m_rank > 0.75 THEN 4
        WHEN m_rank > 0.5 THEN 3
        WHEN m_rank > 0.25 THEN 2
        ELSE 1 END AS m_score
FROM rfm_rank
)
, segmentation AS (
SELECT *
    , CASE WHEN CONCAT(r_score,f_score, m_score) = 111 THEN 'Best Customers'
        WHEN CONCAT(r_score,f_score, m_score) LIKE '[3-4][3-4][1-4]' THEN 'Lost Bad Customers'
        WHEN CONCAT(r_score,f_score, m_score) LIKE '[3-4]2[1-4]' THEN 'Lost Customers'
        WHEN CONCAT(r_score,f_score, m_score) LIKE  '21[1-4]' THEN 'Almost Lost'
        WHEN CONCAT(r_score,f_score, m_score) LIKE  '11[2-4]' THEN 'Loyal Customers'
        WHEN CONCAT(r_score,f_score, m_score) LIKE  '[1-2][1-3]1' THEN 'Big Spenders'
        WHEN CONCAT(r_score,f_score, m_score) LIKE  '[1-2]4[1-4]' THEN 'New Customers'
        WHEN CONCAT(r_score,f_score, m_score) LIKE  '[3-4]1[1-4]' THEN 'Hibernating'
        WHEN CONCAT(r_score,f_score, m_score) LIKE  '[1-2][2-3][2-4]' THEN 'Potential Loyalists'
        ELSE 'unknown'
        END AS segment
FROM rfm_score
)
SELECT segment
    , COUNT(customer_id) AS number_users
    , FORMAT(1.0*COUNT(customer_id)/ SUM(COUNT(customer_id)) OVER(), 'p') AS pct
FROM segmentation
GROUP BY segment
ORDER BY number_users DESC