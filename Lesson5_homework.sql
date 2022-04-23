/* 1. Trending the Data: With time series data, we often want to look for trends in the data. A trend is
simply the direction in which the data is moving. It may be moving up or increasing over time, or it
may be moving down or decreasing over time. It can remain more or less flat, or there could be so
much noise, or movement up and down, that it’s hard to determine a trend at all.*/

/* 1.1. Simple trend
Task: You need to analyze the trend of payment transactions of Billing category from 2019 to 2020. First,
let’s show the trend of the number of successful transaction by month.*/
SELECT MONTH(ft.transaction_time) AS month
    , YEAR(ft.transaction_time) AS year
    , COUNT(ft.transaction_id) AS number_trans
FROM (
    SELECT * FROM dbo.fact_transaction_2019
    UNION
    SELECT * FROM dbo.fact_transaction_2020) ft
JOIN dbo.dim_scenario sc ON sc.scenario_id = ft.scenario_id
WHERE ft.status_id = 1 AND sc.category = 'Billing'
GROUP BY MONTH(ft.transaction_time),YEAR(ft.transaction_time)
ORDER BY 2,1

/* 1.2. Comparing Component
Task: You know that, there are many sub-categories of Billing group. After reviewing the above result,
you should break down the trend into each sub-categories.*/
SELECT MONTH(ft.transaction_time) AS month
    , YEAR(ft.transaction_time) AS year
    , sc.sub_category
    , COUNT(ft.transaction_id) AS number_trans
FROM (
    SELECT * FROM dbo.fact_transaction_2019
    UNION
    SELECT * FROM dbo.fact_transaction_2020) ft
JOIN dbo.dim_scenario sc ON sc.scenario_id = ft.scenario_id
WHERE ft.status_id = 1 AND sc.category = 'Billing'
GROUP BY MONTH(ft.transaction_time),YEAR(ft.transaction_time),sc.sub_category
ORDER BY 2,1

/* Then modify the result as the following table: Only select the sub-categories belong to list (Electricity,
Internet and Water).*/
-- Way 1: Pivot table
SELECT month
    , year
    , [Electricity] AS electricity_trans
    , [Internet] AS internet_trans
    , [Water] AS water_trans
FROM
(
    SELECT MONTH(ft.transaction_time) AS month
        , YEAR(ft.transaction_time) AS year
        , sc.sub_category
        , ft.transaction_id
    FROM (
        SELECT * FROM dbo.fact_transaction_2019
        UNION
        SELECT * FROM dbo.fact_transaction_2020) ft
    JOIN dbo.dim_scenario sc ON sc.scenario_id = ft.scenario_id
    WHERE ft.status_id = 1 AND sc.category = 'Billing'
    GROUP BY MONTH(ft.transaction_time),YEAR(ft.transaction_time),sc.sub_category, ft.transaction_id
) AS source_table
PIVOT
(
    COUNT(transaction_id)
    FOR sub_category IN ([Electricity],[Internet],[Water])
) AS pivot_table

-- Way 2: Group by
WITH sub_count AS
(
    SELECT MONTH(ft.transaction_time) AS month
        , YEAR(ft.transaction_time) AS year
        , sc.sub_category
        , COUNT(ft.transaction_id) AS number_trans
    FROM (
        SELECT * FROM dbo.fact_transaction_2019
        UNION
        SELECT * FROM dbo.fact_transaction_2020) ft
    JOIN dbo.dim_scenario sc ON sc.scenario_id = ft.scenario_id
    WHERE ft.status_id = 1 AND sc.category = 'Billing'
    GROUP BY MONTH(ft.transaction_time),YEAR(ft.transaction_time),sc.sub_category)
SELECT month, year
    , SUM(CASE WHEN sub_category = 'Electricity' THEN number_trans END)  AS electricity_trans
    , SUM(CASE WHEN sub_category = 'Internet' THEN number_trans END)  AS internet_trans
    , SUM(CASE WHEN sub_category = 'Water' THEN number_trans END)  AS water_trans
FROM sub_count
GROUP BY month, year


/* 1.3. Percent of Total Calculations: When working with time series data that has multiple parts or
attributes that constitute a whole, it’s often useful to analyze each part’s contribution to the whole and
whether that has changed over time. Unless the data already contains a time series of the total
values, we’ll need to calculate the overall total in order to calculate the percent of total for each row
Task: Based on the previous query, you need to calculate the proportion of each sub-category
(Electricity, Internet and Water) in the total for each month.*/
WITH summary_table AS
(
    SELECT month
    , year
    , [Electricity] AS electricity_trans
    , [Internet] AS internet_trans
    , [Water] AS water_trans
FROM
(
    SELECT MONTH(ft.transaction_time) AS month
        , YEAR(ft.transaction_time) AS year
        , sc.sub_category
        , ft.transaction_id
    FROM (
        SELECT * FROM dbo.fact_transaction_2019
        UNION
        SELECT * FROM dbo.fact_transaction_2020) ft
        JOIN dbo.dim_scenario sc ON sc.scenario_id = ft.scenario_id
        WHERE ft.status_id = 1 AND sc.category = 'Billing'
        GROUP BY MONTH(ft.transaction_time),YEAR(ft.transaction_time),sc.sub_category, ft.transaction_id
    ) AS source_table
    PIVOT
    (
        COUNT(transaction_id)
        FOR sub_category IN ([Electricity],[Internet],[Water])
    ) AS pivot_table
)
SELECT *
    , electricity_trans+internet_trans+water_trans AS total_trans_month
    , FORMAT(1.0*electricity_trans/(electricity_trans+internet_trans+water_trans),'p') AS electricity_trans_pct
    , FORMAT(1.0*internet_trans/(electricity_trans+internet_trans+water_trans),'p') AS internet_trans_pct
    , FORMAT(1.0*water_trans/(electricity_trans+internet_trans+water_trans),'p') AS water_trans_pct
FROM summary_table

/* 1.4. Indexing to See Percent Change over Time: Indexing data is a way to understand the changes in a
time series relative to a base period (starting point). Indices are widely used in economics as well as
business settings.
Task: Select only these sub-categories in the list (Electricity, Internet and Water), you need to calculate
the number of successful paying customers for each month (from 2019 to 2020). Then find the
percentage change from the first month (Jan 2019) for each subsequent month.*/
WITH summary_table AS
(
    SELECT MONTH(ft.transaction_time) AS month
        , YEAR(ft.transaction_time) AS year
        , COUNT(DISTINCT ft.customer_id) AS number_trans
    FROM (
        SELECT * FROM dbo.fact_transaction_2019
        UNION
        SELECT * FROM dbo.fact_transaction_2020) ft
    JOIN dbo.dim_scenario sc ON sc.scenario_id = ft.scenario_id
    WHERE ft.status_id = 1 AND sc.sub_category IN ('Electricity','Internet','Water')
    GROUP BY MONTH(ft.transaction_time),YEAR(ft.transaction_time)
)
SELECT month
    , year
    , number_trans
    , (SELECT number_trans FROM summary_table WHERE month=1 AND year=2019) AS starting_point
    , LEFT(CAST(ROUND(100.0*(number_trans-(SELECT number_trans FROM summary_table WHERE month=1 AND year=2019))/(SELECT number_trans FROM summary_table WHERE month=1 AND year=2019),2) AS nvarchar),CHARINDEX('.',CAST(ROUND(100.0*(number_trans-(SELECT number_trans FROM summary_table WHERE month=1 AND year=2019))/(SELECT number_trans FROM summary_table WHERE month=1 AND year=2019),2) AS nvarchar))+2) + '%' AS pct_from_starting_point   
FROM summary_table


-- Extract month and year
SELECT DISTINCT LEFT(CONVERT(VARCHAR(3),transaction_time,101),3) + RIGHT(CONVERT(VARCHAR(20),transaction_time,101),2)
FROM dbo.fact_transaction_2019
ORDER BY 1
