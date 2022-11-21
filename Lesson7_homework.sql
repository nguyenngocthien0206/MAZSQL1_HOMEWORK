-- 1. Task 1: Retrieve reports on transaction scenarios and status
/* 1.1. Retrieve a report that includes the following information: customer_id, transaction_id,
scenario_id, transaction_type, sub_category, category and status_description. 
These transactions must meet the
following conditions:
- Were created in Jan 2020
- Status is successful.*/
SELECT ft.customer_id
	, ft.transaction_id
	, ft.scenario_id
	, sc.transaction_type
	, sc.sub_category
	, sc.category
	, st.status_description
FROM dbo.fact_transaction_2019 ft
JOIN dbo.dim_scenario sc ON sc.scenario_id = ft.scenario_id
JOIN dbo.dim_status st ON st.status_id = ft.status_id
WHERE ft.status_id = 1
ORDER BY 1

/*1.2. Based on your previous query, let’s calculate the Success Rate of each transaction_type. The desired
outcome has the following columns:
- Transaction type
- Number of transaction
- Number of successful transaction
- Success rate = Number of successful transaction/ Number of transaction.*/
WITH summary_table AS
(
	SELECT ft.customer_id
		, ft.transaction_id
		, ft.scenario_id
		, sc.transaction_type
		, sc.sub_category
		, sc.category
		, st.status_description
	FROM dbo.fact_transaction_2019 ft
	JOIN dbo.dim_scenario sc ON sc.scenario_id = ft.scenario_id
	JOIN dbo.dim_status st ON st.status_id = ft.status_id)
, trans_count AS
(
	SELECT transaction_type
		, COUNT(transaction_id) AS number_trans
	FROM summary_table
	GROUP BY transaction_type)
, success_trans_count AS
(
	SELECT transaction_type
		, COUNT(transaction_id) AS number_success_trans
	FROM summary_table
	WHERE status_description = 'Success'
	GROUP BY transaction_type)
SELECT tc.transaction_type 
	, tc.number_trans
	, stc.number_success_trans
	, FORMAT(1.0*stc.number_success_trans/tc.number_trans,'p') AS pct_success_trans
FROM trans_count tc
JOIN success_trans_count stc ON stc.transaction_type = tc.transaction_type

-- 2. Task 2: Why is the success rate of Top-up so bad?
/* 2.1. Evaluate the success rate of this type by breaking it down into deeper dimensions:
- scenario_id
- payment platform
- payment channel.*/
WITH summary_table AS
(
	SELECT ft.customer_id
			, ft.transaction_id
			, ft.scenario_id
			, sc.transaction_type
			, pc.payment_method
			, pl.payment_platform
			, st.status_description
	FROM dbo.fact_transaction_2019 ft
	JOIN dbo.dim_scenario sc ON sc.scenario_id = ft.scenario_id
	JOIN dbo.dim_status st ON st.status_id = ft.status_id
	JOIN dbo.dim_payment_channel pc ON pc.payment_channel_id = ft.payment_channel_id
	JOIN dbo.dim_platform pl ON pl.platform_id = ft.platform_id)
, trans_type_count AS
(
	SELECT transaction_type
		, COUNT(transaction_id) AS number_trans
	FROM summary_table
	GROUP BY transaction_type)
, success_trans_type_count AS
(
	SELECT transaction_type
		, COUNT(transaction_id) AS number_success_trans
	FROM summary_table
	WHERE status_description = 'Success'
	GROUP BY transaction_type)
, payment_method_count AS
(
	SELECT payment_method
		, COUNT(transaction_id) AS number_trans
	FROM summary_table
	GROUP BY payment_method)
, success_payment_method_count AS
(
	SELECT payment_method
		, COUNT(transaction_id) AS number_success_trans
	FROM summary_table
	WHERE status_description = 'Success'
	GROUP BY payment_method)
, payment_platform_count AS
(
	SELECT payment_platform
		, COUNT(transaction_id) AS number_trans
	FROM summary_table
	GROUP BY payment_platform)
, success_payment_platform_count AS
(
	SELECT payment_platform
		, COUNT(transaction_id) AS number_success_trans
	FROM summary_table
	WHERE status_description = 'Success'
	GROUP BY payment_platform)
SELECT ttc.transaction_type
	, ttc.number_trans
	, sttc.number_success_trans
	, FORMAT(1.0*sttc.number_success_trans/ttc.number_trans,'p') AS pct_success_trans
FROM trans_type_count ttc
JOIN success_trans_type_count sttc ON sttc.transaction_type = ttc.transaction_type
/*
SELECT ttc.payment_method
	, ttc.number_trans
	, sttc.number_success_trans
	, FORMAT(1.0*sttc.number_success_trans/ttc.number_trans,'p') AS pct_success_trans
FROM payment_method_count ttc
JOIN success_payment_method_count sttc ON sttc.payment_method = ttc.payment_method
SELECT ttc.payment_platform
	, ttc.number_trans
	, sttc.number_success_trans
	, FORMAT(1.0*sttc.number_success_trans/ttc.number_trans,'p') AS pct_success_trans
FROM payment_platform_count ttc
JOIN success_payment_platform_count sttc ON sttc.payment_platform = ttc.payment_platform*/

/* 2.2. Apply time series analysis to find the root causes of poor payment platforms and bad payment
channels.*/
CREATE PROC sp_get_success_trans_rate_by_platform @platform NVARCHAR(10)
AS
BEGIN
WITH android_count AS
(
	SELECT MONTH(ft.transaction_time) AS month
		, pl.payment_platform
		, COUNT(ft.transaction_id) AS number_trans
	FROM dbo.fact_transaction_2019 ft
	JOIN dbo.dim_platform pl ON pl.platform_id = ft.platform_id
	WHERE pl.payment_platform = @platform
	GROUP BY MONTH(ft.transaction_time), pl.payment_platform)
, android_success_count AS
(	
	SELECT MONTH(ft.transaction_time) AS month
		, pl.payment_platform
		, COUNT(ft.transaction_id) AS number_success_trans
	FROM dbo.fact_transaction_2019 ft
	JOIN dbo.dim_platform pl ON pl.platform_id = ft.platform_id
	WHERE pl.payment_platform = @platform AND ft.status_id = 1
	GROUP BY MONTH(ft.transaction_time), pl.payment_platform)
SELECT anc.month
	, anc.payment_platform
	, anc.number_trans
	, anst.number_success_trans
	, FORMAT(1.0*anst.number_success_trans/anc.number_trans,'p') AS pct_success_trans
FROM android_count anc
JOIN android_success_count anst ON anst.month = anc.month
END

EXEC sp_get_success_trans_rate_by_platform 'android'
EXEC sp_get_success_trans_rate_by_platform 'ios'
