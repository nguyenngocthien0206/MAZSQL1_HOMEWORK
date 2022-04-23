-- 1. Task 1: Retrieve an overview report of payment types
/* 1.1. Paytm has a wide variety of transaction types in its business. Your manager wants to know the
contribution (by percentage) of each transaction type to total transactions. Retrieve a report that
includes the following information: transaction type, number of transaction and proportion of each
type in total. These transactions must meet the following conditions:
- Were created in 2019
- Were paid successfully
Show only the results of the top 5 types with the highest percentage of the total.*/
SELECT TOP 5 sc.transaction_type
    , COUNT(DISTINCT ft.transaction_id) as num_of_trans
    , COUNT(DISTINCT ft.transaction_id)*100.0/(SELECT COUNT(*) FROM dbo.fact_transaction_2019) as percentage
FROM dbo.fact_transaction_2019 ft
LEFT JOIN dbo.dim_scenario sc ON sc.scenario_id = ft.scenario_id
LEFT JOIN dbo.dim_status st ON st.status_id = ft.status_id 
WHERE st.status_description = 'success'
GROUP BY sc.transaction_type
ORDER BY [percentage] DESC

/* 1.2. After your manager looks at the results these top 5 types, he wants to deep dive more to gain more
insights.
Retrieve a more detailed report with following information: transaction type, category, number of
transaction and proportion of each category in the total of that transaction type. These transactions
must meet the following conditions:
- Were created in 2019
- Were paid successfully.*/
WITH trans_type_count(transaction_type,category,num_of_trans)
AS (
    SELECT s.transaction_type
        , s.category
        , COUNT(*) as num_of_trans
    FROM dbo.fact_transaction_2019 ft
    LEFT JOIN dbo.dim_scenario s ON s.scenario_id = ft.scenario_id
    LEFT JOIN dbo.dim_status st ON st.status_id = ft.status_id 
    WHERE st.status_description = 'success'
    GROUP BY s.transaction_type, s.category)
, category_count(transaction_type,num_of_trans)
AS (
    SELECT s.transaction_type
        , COUNT(*) AS num_of_trans
    FROM dbo.fact_transaction_2019 ft
    LEFT JOIN dbo.dim_scenario s ON s.scenario_id = ft.scenario_id
    LEFT JOIN dbo.dim_status st ON st.status_id = ft.status_id 
    WHERE st.status_description = 'success'
    GROUP BY s.transaction_type)
SELECT trans_type_count.transaction_type
    , trans_type_count.category
    , trans_type_count.num_of_trans
    , category_count.num_of_trans AS total_count
    , trans_type_count.num_of_trans*100.0/category_count.num_of_trans AS percentage
FROM trans_type_count
LEFT JOIN category_count ON category_count.transaction_type = trans_type_count.transaction_type

-- 2. Task 2: Retrieve an overview report of customer’s payment behaviors
/* 2.1. Paytm has acquired a lot of customers. Retrieve a report that includes the following information: the
number of transactions, the number of payment scenarios, the number of transaction types, the
number of payment category and the total of charged amount of each customer.
- Were created in 2019
- Had status description is successful
- Had transaction type is payment
- Only show Top 10 highest customers by the number of transactions.*/
SELECT TOP 10 ft.customer_id
    , COUNT(ft.transaction_id) AS number_trans
    , COUNT(DISTINCT ft.scenario_id) AS number_scenarios
    , COUNT(DISTINCT sc.transaction_type) AS number_types
    , COUNT(DISTINCT sc.category) AS number_categories
    , SUM(ft.charged_amount) AS total_amount
FROM dbo.fact_transaction_2019 ft
LEFT JOIN dbo.dim_scenario sc ON ft.scenario_id = sc.scenario_id
LEFT JOIN dbo.dim_status st ON ft.status_id = st.status_id
WHERE st.status_description = 'success' AND sc.transaction_type = 'payment'
GROUP BY customer_id
ORDER BY number_trans DESC

/* 2.2. After looking at the above metrics of customer’s payment behaviors, we want to analyze the
distribution of each metric. Before calculating and plotting the distribution to check the frequency of
values in each metric, we need to group the observations into range.
    2.2.1. How can we group the observations in the most logical way? Binning is useful to help us
    deal with problem. To use binning method, we need to determine how many bins for each
    distribution of each field.
Retrieve a report that includes the following columns: metric, minimum value, maximum value and
average value of these metrics:
- The total charged amount
- The number of transactions
- The number of payment scenarios
- The number of payment categories.*/
WITH summary_table
AS (
    SELECT ft.customer_id
    , COUNT(ft.transaction_id) AS number_trans
    , COUNT(DISTINCT ft.scenario_id) AS number_scenarios
    , COUNT(DISTINCT sc.transaction_type) AS number_types
    , COUNT(DISTINCT sc.category) AS number_categories
    , SUM(ft.charged_amount) AS total_amount
    FROM dbo.fact_transaction_2019 ft
    LEFT JOIN dbo.dim_scenario sc ON ft.scenario_id = sc.scenario_id
    LEFT JOIN dbo.dim_status st ON ft.status_id = st.status_id
    WHERE st.status_description = 'success' AND sc.transaction_type = 'payment'
    GROUP BY customer_id)
SELECT 'The number of transactions' AS metric
    , MIN(number_trans) AS min_value
    , MAX(number_trans) AS max_value
    , AVG(number_trans) AS avg_value
FROM summary_table
UNION
SELECT 'The number of payment scenarios' AS metric
    , MIN(number_scenarios) AS min_value
    , MAX(number_scenarios) AS max_value
    , AVG(number_scenarios) AS avg_value
FROM summary_table
UNION
SELECT 'The number of payment categories' AS metric
    , MIN(number_categories) AS min_value
    , MAX(number_categories) AS max_value
    , AVG(number_categories) AS avg_value
FROM summary_table
UNION
SELECT 'The total charge amount' AS metric
    , MIN(total_amount) AS min_value
    , MAX(total_amount) AS max_value
    , AVG(1.0*total_amount) AS avg_value
FROM summary_table

/* 2.2.2. Bin the total charged amount and number of transactions then calculate the frequency of
each field in each metric.*/
-- Metric 1: The total charged amount
WITH summary_table(customer_id,total_amount,charge_amount_range)
AS (
    SELECT ft.customer_id
    , SUM(ft.charged_amount) AS total_amount
    , CASE
        WHEN SUM(ft.charged_amount) < 1000000 THEN '0M-1M'
        WHEN SUM(ft.charged_amount) >= 1000000 AND SUM(ft.charged_amount) < 2000000 THEN '1M-2M'
        WHEN SUM(ft.charged_amount) >= 2000000 AND SUM(ft.charged_amount) < 3000000 THEN '2M-3M'
        WHEN SUM(ft.charged_amount) >= 3000000 AND SUM(ft.charged_amount) < 4000000 THEN '3M-4M'
        WHEN SUM(ft.charged_amount) >= 4000000 AND SUM(ft.charged_amount) < 5000000 THEN '4M-5M'
        WHEN SUM(ft.charged_amount) >= 5000000 AND SUM(ft.charged_amount) < 6000000 THEN '5M-6M'
        WHEN SUM(ft.charged_amount) >= 6000000 AND SUM(ft.charged_amount) < 7000000 THEN '6M-7M'
        WHEN SUM(ft.charged_amount) >= 7000000 AND SUM(ft.charged_amount) < 8000000 THEN '7M-8M'
        WHEN SUM(ft.charged_amount) >= 8000000 AND SUM(ft.charged_amount) < 9000000 THEN '8M-9M'
        WHEN SUM(ft.charged_amount) >= 9000000 AND SUM(ft.charged_amount) < 10000000 THEN '9M-10M'
        WHEN SUM(ft.charged_amount) >= 1000000 THEN '> 10M'
        END AS charge_amount_range
    FROM dbo.fact_transaction_2019 ft
    LEFT JOIN dbo.dim_scenario sc ON ft.scenario_id = sc.scenario_id
    LEFT JOIN dbo.dim_status st ON ft.status_id = st.status_id
    WHERE st.status_description = 'success' AND sc.transaction_type = 'payment'
    GROUP BY customer_id)
SELECT charge_amount_range
    , COUNT(customer_id) as number_customers
FROM summary_table
GROUP BY charge_amount_range

-- Metric 2: The number of transactions
WITH summary_table(customer_id,number_trans,number_trans_range)
AS (
    SELECT ft.customer_id
    , COUNT(ft.transaction_id) AS number_trans
    , CASE
        WHEN COUNT(ft.transaction_id) < 10 THEN '0-10'
        WHEN COUNT(ft.transaction_id) >= 10 AND COUNT(ft.transaction_id) < 20 THEN '10-20'
        WHEN COUNT(ft.transaction_id) >= 20 AND COUNT(ft.transaction_id) < 30 THEN '20-30'
        WHEN COUNT(ft.transaction_id) >= 30 AND COUNT(ft.transaction_id) < 40 THEN '30-40'
        WHEN COUNT(ft.transaction_id) >= 40 AND COUNT(ft.transaction_id) < 50 THEN '40-50'
        WHEN COUNT(ft.transaction_id) >= 50 AND COUNT(ft.transaction_id) < 60 THEN '50-60'
        WHEN COUNT(ft.transaction_id) >= 60 AND COUNT(ft.transaction_id) < 70 THEN '60-70'
        WHEN COUNT(ft.transaction_id) >= 70 AND COUNT(ft.transaction_id) < 80 THEN '70-80'
        WHEN COUNT(ft.transaction_id) >= 80 AND COUNT(ft.transaction_id) < 90 THEN '80-90'
        WHEN COUNT(ft.transaction_id) >= 90 AND COUNT(ft.transaction_id) < 100 THEN '90-100'
        WHEN COUNT(ft.transaction_id) >= 100 THEN '> 100'
        END AS number_trans_range
    FROM dbo.fact_transaction_2019 ft
    LEFT JOIN dbo.dim_scenario sc ON ft.scenario_id = sc.scenario_id
    LEFT JOIN dbo.dim_status st ON ft.status_id = st.status_id
    WHERE st.status_description = 'success' AND sc.transaction_type = 'payment'
    GROUP BY customer_id)
SELECT number_trans_range
    , COUNT(customer_id) as number_customers
FROM summary_table
GROUP BY number_trans_range

-- Metric 3: The number of payment categories
WITH summary_table(customer_id,number_categories,number_categories_range)
AS (
    SELECT ft.customer_id
    , COUNT(sc.category) AS number_categories
    , CASE
        WHEN COUNT(sc.category) = 1 THEN 1
        WHEN COUNT(sc.category) = 2 THEN 2
        WHEN COUNT(sc.category) = 3 THEN 3
        WHEN COUNT(sc.category) = 4 THEN 4
        WHEN COUNT(sc.category) = 5 THEN 5
        WHEN COUNT(sc.category) = 6 THEN 6
        WHEN COUNT(sc.category) = 7 THEN 7
        END AS number_categories_range
    FROM dbo.fact_transaction_2019 ft
    LEFT JOIN dbo.dim_scenario sc ON ft.scenario_id = sc.scenario_id
    LEFT JOIN dbo.dim_status st ON ft.status_id = st.status_id
    WHERE st.status_description = 'success' AND sc.transaction_type = 'payment'
    GROUP BY customer_id)
SELECT number_categories_range
    , COUNT(customer_id) as number_customers
FROM summary_table
GROUP BY number_categories_range

-- Metric 4: The number of payment scenarios
WITH summary_table(customer_id,number_scenarios,number_scenarios_range)
AS (
    SELECT ft.customer_id
    , COUNT(ft.scenario_id) AS number_scenarios
    , CASE
        WHEN COUNT(ft.scenario_id) = 1 THEN 1
        WHEN COUNT(ft.scenario_id) = 2 THEN 2
        WHEN COUNT(ft.scenario_id) = 3 THEN 3
        WHEN COUNT(ft.scenario_id) = 4 THEN 4
        WHEN COUNT(ft.scenario_id) = 5 THEN 5
        WHEN COUNT(ft.scenario_id) = 6 THEN 6
        WHEN COUNT(ft.scenario_id) = 7 THEN 7
        WHEN COUNT(ft.scenario_id) = 8 THEN 8
        WHEN COUNT(ft.scenario_id) = 9 THEN 9
        WHEN COUNT(ft.scenario_id) = 10 THEN 10
        WHEN COUNT(ft.scenario_id) = 11 THEN 11
        WHEN COUNT(ft.scenario_id) = 12 THEN 12
        WHEN COUNT(ft.scenario_id) = 13 THEN 13
        WHEN COUNT(ft.scenario_id) = 14 THEN 14
        WHEN COUNT(ft.scenario_id) = 15 THEN 15
        WHEN COUNT(ft.scenario_id) = 16 THEN 16
        WHEN COUNT(ft.scenario_id) = 17 THEN 17
        END AS number_categories_range
    FROM dbo.fact_transaction_2019 ft
    LEFT JOIN dbo.dim_scenario sc ON ft.scenario_id = sc.scenario_id
    LEFT JOIN dbo.dim_status st ON ft.status_id = st.status_id
    WHERE st.status_description = 'success' AND sc.transaction_type = 'payment'
    GROUP BY customer_id)
SELECT number_scenarios_range
    , COUNT(customer_id) as number_customers
FROM summary_table
GROUP BY number_scenarios_range