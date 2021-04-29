--Estimated Time taken to Complete the challenge : 1 hour

--Challenge 1:
--The leadership team has asked us to graph total monthly sales over time. Write a query that returns the data we need to complete this request.

SELECT 
	  YEAR(I.InvoiceDate) AS InvoiceYear
	, DATENAME(MONTH,I.InvoiceDate) AS InvoiceMonth
	, SUM(IL.ExtendedPrice) AS TotalMonthlyRevenue
FROM Sales.Invoices I
INNER JOIN Sales.InvoiceLines IL ON IL.InvoiceID = I.InvoiceID
GROUP BY 
	  YEAR(I.InvoiceDate), DATENAME(MONTH,I.InvoiceDate)
ORDER BY InvoiceYear, InvoiceMonth


--Challenge 2:
--What is the fastest growing customer category in Q1 2016 (compared to same quarter sales in the previous year)? What is the growth rate?

WITH Yearly_Sales AS
(
	SELECT 
		  CustomerCategoryName
		, [2015] AS Sales_2015
		, [2016] AS Sales_2016
	FROM
	(
		SELECT 
			   CC.CustomerCategoryName
			 , YEAR(I.InvoiceDate) AS InvoiceYear
			 , SUM(IL.ExtendedPrice) AS Sales
		FROM Sales.CustomerCategories CC
		INNER JOIN Sales.Customers C ON C.CustomerCategoryID = CC.CustomerCategoryID
		INNER JOIN Sales.Invoices I ON I.CustomerID = C.CustomerID
		INNER JOIN Sales.InvoiceLines IL ON IL.InvoiceID = I.InvoiceID
		WHERE YEAR(I.InvoiceDate) IN (2016,2015) 
			AND DATEPART(QUARTER,I.InvoiceDate) = 1
		GROUP BY CC.CustomerCategoryName, YEAR(I.InvoiceDate), DATEPART(QUARTER,I.InvoiceDate)
	) t
	PIVOT (
		SUM(Sales)
		FOR InvoiceYear IN
		([2015], [2016])
	) AS pivot_table
)
SELECT TOP 1
	  CustomerCategoryName
	, (Sales_2016 - Sales_2015) * 100 / Sales_2015 AS GrowthRate
FROM Yearly_Sales
ORDER BY GrowthRate DESC


--Challenge 3:
--Write a query to return the list of suppliers that WWI has purchased from, along with # of invoices paid, # of invoices still outstanding, and average invoice amount.

SELECT
	  S.SupplierID	
	, S.SupplierName
	, SUM(CASE WHEN ST.OutstandingBalance = 0 THEN 1 ELSE 0 END) AS PaidInvoicesCount
	, SUM(CASE WHEN ST.OutstandingBalance <> 0 THEN 1 ELSE 0 END) AS OutstandingInvoicesCount
	, SUM(ST.AmountExcludingTax + ST.TaxAmount) / COUNT(ST.SupplierTransactionID) AS AvgInvoiceAmount
FROM Purchasing.Suppliers S
INNER JOIN Purchasing.SupplierTransactions ST ON S.SupplierID = ST.SupplierID
GROUP BY S.SupplierID, S.SupplierName
ORDER BY S.SupplierID


--Challenge 4:
--Using "unit price" and "recommended retail price", which item in the warehouse has the lowest gross profit amount? Which item has the highest? What is the median gross profit across all items in the warehouse?

--Calculating total sold quantity for each stockItem
WITH StockItem_SoldQuantity AS
(
	SELECT 
		  StockItemID
		, SUM(Quantity) AS SoldQuantity
	FROM Sales.InvoiceLines
	GROUP BY StockItemID
)
--Calculating Gross Profit for StockItem using UnitPrice and RecommendationRetailPrice
, StockItem_Metrics AS
(
	SELECT 
		  SI.StockItemID
		, SI.StockItemName
		, (SI.RecommendedRetailPrice - SI.UnitPrice) * SS.SoldQuantity AS GrossProfit
	FROM Warehouse.StockItems SI
	INNER JOIN StockItem_SoldQuantity SS ON SS.StockItemID = SI.StockItemID
)
--Calculating Lowest Gross Profit item
SELECT 
	  'Lowest Gross Profit Item/Amount' AS Metric
	, SM.StockItemID
	, SM.StockItemName
	, min_profit.LowestGrossProfit AS Amount
FROM StockItem_Metrics SM
INNER JOIN (
	SELECT MIN(GrossProfit) AS LowestGrossProfit
	FROM StockItem_Metrics
	) min_profit ON min_profit.LowestGrossProfit = SM.GrossProfit

UNION

--Calculating Highest Gross Profit item
SELECT 
	   'Highest Gross Profit Item/Amount' AS Metric
	 , SM.StockItemID
	 , SM.StockItemName
	 , max_profit.HighestGrossProfit AS Amount
FROM StockItem_Metrics SM
INNER JOIN (
	SELECT MAX(GrossProfit) AS HighestGrossProfit
	FROM StockItem_Metrics
	) max_profit ON max_profit.HighestGrossProfit = SM.GrossProfit

UNION

--Calculating Median Gross Profit amount along with the item name at the median position
SELECT 
	  'Median Gross Profit Item/Amount' AS Metric
	, SM.StockItemID
	, SM.StockItemName
	, med_profit.MedianGrossProfit AS Amount
FROM StockItem_Metrics SM
INNER JOIN (
	SELECT StockItemID
	,PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY GrossProfit) OVER() AS MedianGrossProfit
FROM StockItem_Metrics
	) med_profit ON med_profit.MedianGrossProfit = SM.GrossProfit
