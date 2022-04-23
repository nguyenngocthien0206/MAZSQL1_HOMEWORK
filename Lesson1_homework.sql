USE AdventureWorksLT2019
GO

-- Task 1: Retrieve data for transportation reports
-- 1.1 Retrieve a list of cities
SELECT DISTINCT City, StateProvince
FROM SalesLT.Address
ORDER BY StateProvince ASC,
		City DESC

-- 1.2 Retrieve the heaviest products information
SELECT TOP 10 PERCENT Name, Weight
FROM SalesLT.Product
ORDER BY Weight DESC

-- Task 2: Retrieve product data
-- 2.1 Filter products by color and size
SELECT ProductNumber, Name
FROM SalesLT.Product
WHERE Color IN ('Black','Red','White') OR Size IN ('S','M')

-- 2.2 Filter products by color, size and product number
SELECT ProductID, ProductNumber, Name
FROM SalesLT.Product
WHERE ProductNumber LIKE 'BK-[^T]%-[0-9][0-9]'
	AND (Color IN ('Black','Red','White') OR Size IN ('S','M'))

-- 2.3 Retrieve specific products by product ID
SELECT ProductID, ProductNumber, Name, ListPrice
FROM SalesLT.Product
WHERE (Name LIKE '%HL%' OR Name LIKE '%Mountain%')
	AND ProductNumber LIKE '________%'
	AND ProductID NOT IN (
							SELECT DISTINCT ProductID
							FROM SalesLT.SalesOrderDetail)