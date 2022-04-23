-- COHORT ANALYSIS METHOD
-- 1. Retention
-- 1.1. Basic Retention Curve:
/* Task:
A. As you know that 'Telco Card' is the most product in the Telco group (accounting for more
than 99% of the total). You want to evaluate the quality of user acquisition in Jan 2019 by the
retention metric. First, you need to know how many users are retained in each subsequent
month from the first month (Jan 2019) they pay the successful transaction (only get data of
2019).*/
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
SELECT (urm.retention_month-ufm.first_month) AS subsequent_month
    , COUNT(urm.customer_id) AS retained_users
FROM user_retention_month urm
LEFT JOIN user_first_month ufm ON ufm.customer_id = urm.customer_id
WHERE ufm.first_month = 1
GROUP BY (urm.retention_month-ufm.first_month)
ORDER BY 1,2

/* B. You realize that the number of retained customers has decreased over time. Let’s calculate
retention = number of retained customers / total users of the first month.*/
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
    SELECT (urm.retention_month-ufm.first_month) AS subsequent_month
        , COUNT(urm.customer_id) AS retained_users
    FROM user_retention_month urm
    LEFT JOIN user_first_month ufm ON ufm.customer_id = urm.customer_id
    WHERE ufm.first_month = 1
    GROUP BY (urm.retention_month-ufm.first_month))
SELECT subsequent_month
    , retained_users
    , FIRST_VALUE(retained_users) OVER(ORDER BY subsequent_month) AS origial_users
    , FORMAT(1.0*retained_users/(FIRST_VALUE(retained_users) OVER(ORDER BY subsequent_month)),'p')  AS pct_retained
FROM summary_table

-- 1.2. Cohorts Derived from the Time Series Itself
/* Task: Expend your previous query to calculate retention for multi attributes from the acquisition
month (from Jan to December).*/
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

-- Then modify the result as the following table:
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


-- 2. USER SEGMENTATION
/* 2.1. The first step in building an RFM model is to assign Recency, Frequency and Monetary values to
each customer. Let’s calculate these metrics for all successful paying customer of ‘Telco Card’ in
2019 and 2020:*/
SELECT ft.customer_id
	, DATEDIFF(day,MAX(ft.transaction_time),'2020-12-31') AS R
	, COUNT(ft.transaction_id) AS F
	, SUM(1.0*ft.charged_amount) AS M
FROM dbo.fact_transaction_2019 ft
JOIN dbo.dim_scenario sc ON sc.scenario_id = ft.scenario_id
WHERE ft.status_id = 1 AND sc.sub_category = 'Telco Card'
GROUP BY customer_id