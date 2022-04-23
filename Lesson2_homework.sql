USE AdventureWorksLT2019
GO

--TASK 1
/*1.1 Retrieve customer names and phone numbers
Each customer has an assigned salesperson. You must write a query to create a call
sheet that lists:
- The salesperson
- A column named CustomerName that displays how the customer contact should
be greeted (for example, Mr Smith)
- The customer’s phone number.*/
SELECT CustomerID
	,ISNULL(Title,'') + FirstName + ' ' + ISNULL(MiddleName + ' ','') + LastName AS CustomerName
	, SUBSTRING(SalesPerson,CHARINDEX('\',SalesPerson)+1,LEN(SalesPerson)) AS SalesPerson
FROM SalesLT.Customer

/*1.2 Retrieve the heaviest products information
Transportation costs are increasing and you need to identify the heaviest products. Retrieve the
names, weight of the top ten percent of products by weight.
Then, add new column named Number of sell days (caculated from SellStartDate and SellEndDate)
of these products (if sell end date is'nt defined then get Today date)*/
SELECT TOP 10 PERCENT Name, Weight,
CASE
	WHEN SellEndDate IS NULL THEN DATEDIFF(day,SellStartDate,GETDATE())
	ELSE DATEDIFF(day,SellStartDate,SellEndDate)
END AS NumberOfSellDays
FROM SalesLT.Product
ORDER BY Weight DESC


--TASK 2: Retrieve customer order data
/*2.1 As you continue to work with the Adventure Works customer data, you must create
queries for reports that have been requested by the sales team.
Retrieve a list of customer companies
- You have been asked to provide a list of all customer companies in the
format Customer ID : Company Name - for example, 78: Preferred Bikes*/
SELECT CustomerID, CompanyName
FROM SalesLT.Customer

/*2.2 Retrieve a list of sales order revisions
The SalesLT.SalesOrderHeader table contains records of sales orders. You have
been asked to retrieve data for a report that shows:
- The sales order number and revision number in the format () – for example
SO71774 (2).
- The order date converted to ANSI standard 102 format (yyyy.mm.dd – for
example 2015.01.31).*/
SELECT SalesOrderID
	, SalesOrderNumber + ' (' + TRIM(STR(RevisionNumber)) + ')' AS SalesOrderNum
	, CONVERT(nvarchar,OrderDate,102) AS OrderDate
FROM SalesLT.SalesOrderHeader

--TASK 3: Retrieve customer contact details
/*3.1 Some records in the database include missing or unknown values that are returned
as NULL. You must create some queries that handle these NULL values appropriately.
Retrieve customer contact names with middle names if known
o You have been asked to write a query that returns a list of customer names.
The list must consist of a single column in the format first last (for
example Keith Harris) if the middle name is unknown, or first middle last (for
example Jane M. Gates) if a middle name is known.*/
SELECT CASE
	WHEN MiddleName IS NULL THEN FirstName + ' ' + LastName
	ELSE FirstName + ' ' + MiddleName + ' ' + LastName
	END AS CustomerName
FROM SalesLT.Customer

/*3.2 Retrieve primary contact details
o Customers may provide Adventure Works with an email address, a phone
number, or both. If an email address is available, then it should be used as
the primary contact method; if not, then the phone number should be used.
You must write a query that returns a list of customer IDs in one column, and
a second column named PrimaryContact that contains the email address if
known, and otherwise the phone number.*/
SELECT CustomerID
	, CASE
		WHEN EmailAddress IS NOT NULL THEN EmailAddress
		WHEN (EmailAddress IS NULL) AND (Phone IS NOT NULL) THEN Phone
		ELSE NULL
		END AS Contact
FROM SalesLT.Customer

/*3.3 As you continue to work with the Adventure Works customer, product and sales
data, you must create queries for reports that have been requested by the sales team.
Retrieve a list of customers with no address
o A sales employee has noticed that Adventure Works does not have address
information for all customers. You must write a query that returns a list of
customer IDs, company names, contact names (first name and last name),
and phone numbers for customers with no address stored in the database.*/
SELECT CustomerID, CompanyName, FirstName + ' ' + LastName AS CustomerName, Phone
FROM SalesLT.Customer
WHERE CustomerID NOT IN (
					SELECT CustomerID FROM SalesLT.CustomerAddress)
