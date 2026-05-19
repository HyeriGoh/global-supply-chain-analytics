-- Create Staging tables

USE SupplyChainBI;
GO

-- Drop if exists
IF OBJECT_ID('stg_orders') IS NOT NULL DROP TABLE stg_orders;
IF OBJECT_ID('stg_shipments') IS NOT NULL DROP TABLE stg_shipments;
IF OBJECT_ID('stg_customers') IS NOT NULL DROP TABLE stg_customers;
IF OBJECT_ID('stg_products') IS NOT NULL DROP TABLE stg_products;
IF OBJECT_ID('stg_suppliers') IS NOT NULL DROP TABLE stg_suppliers;
IF OBJECT_ID('stg_warehouses') IS NOT NULL DROP TABLE stg_warehouses;
IF OBJECT_ID('stg_inventory') IS NOT NULL DROP TABLE stg_inventory;
GO


-- 7 staging tables for 7 clean csv files
CREATE TABLE stg_customers (
    CustomerID INT,
    Segment VARCHAR(50),
    Country VARCHAR(50),
    Region VARCHAR(50)
);

CREATE TABLE stg_products (
    ProductID INT,
    Category VARCHAR(50),
    BasePrice DECIMAL(18,2)
);

CREATE TABLE stg_suppliers (
    SupplierID INT,
    ProductID INT,
    Country VARCHAR(50),
    LeadTimeDays INT
);

CREATE TABLE stg_warehouses (
    WarehouseID INT,
    WarehouseName VARCHAR(100),
    Region VARCHAR(50)
);

CREATE TABLE stg_orders (
    OrderID INT,
    OrderDate DATE,
    CustomerID INT,
    ProductID INT,
    Quantity INT,
    UnitPrice DECIMAL(18,2),
    Revenue DECIMAL(18,2)
);

CREATE TABLE stg_shipments (
    ShipmentID INT,
    OrderID INT,
	WarehouseID INT,
    ShipDate DATE,
    DeliveryDate DATE,
    CarrierName VARCHAR(50),
    DeliveryDays INT,
	CustomerID INT,
	Region VARCHAR(50),
    OnTimeFlag BIT
);




CREATE TABLE stg_inventory (
    WarehouseID INT,
	ProductID INT,
	StockQuantity INT,
	ReorderLevel INT,
	InventoryDate DATE    
);


-- Load clean CSV into Staging
BULK INSERT stg_customers
FROM 'C:\Users\hyeri\Desktop\GlobalSupplyChainAnalytics\data\cleaned\clean_customers.csv'
WITH (FORMAT='CSV', FIRSTROW=2);

BULK INSERT stg_products
FROM 'C:\Users\hyeri\Desktop\GlobalSupplyChainAnalytics\data\cleaned\clean_products.csv'
WITH (FORMAT='CSV', FIRSTROW=2);

BULK INSERT stg_suppliers
FROM 'C:\Users\hyeri\Desktop\GlobalSupplyChainAnalytics\data\cleaned\clean_suppliers.csv'
WITH (FORMAT='CSV', FIRSTROW=2);

BULK INSERT stg_warehouses
FROM 'C:\Users\hyeri\Desktop\GlobalSupplyChainAnalytics\data\cleaned\clean_warehouses.csv'
WITH (FORMAT='CSV', FIRSTROW=2);

BULK INSERT stg_orders
FROM 'C:\Users\hyeri\Desktop\GlobalSupplyChainAnalytics\data\cleaned\clean_orders.csv'
WITH (FORMAT='CSV', FIRSTROW=2);

BULK INSERT stg_shipments
FROM 'C:\Users\hyeri\Desktop\GlobalSupplyChainAnalytics\data\cleaned\clean_shipments.csv'
WITH (FORMAT='CSV', FIRSTROW=2);

BULK INSERT stg_inventory
FROM 'C:\Users\hyeri\Desktop\GlobalSupplyChainAnalytics\data\cleaned\clean_inventory.csv'
WITH (FORMAT='CSV', FIRSTROW=2);


-- Load dimention tables
-- DimCustomer
INSERT INTO DimCustomer (CustomerID, Segment, Country, Region)
SELECT DISTINCT
    CustomerID,
    Segment,
    Country,
    Region
FROM stg_customers;


-- DimProduct
INSERT INTO DimProduct (ProductID, Category, BasePrice)
SELECT DISTINCT
    ProductID,
    Category,
    BasePrice
FROM stg_products;


--DimSupplier
INSERT INTO DimSupplier (SupplierID, ProductID, Country, LeadTimeDays)
SELECT DISTINCT
    SupplierID,
    ProductID,
    Country,
    LeadTimeDays
FROM stg_suppliers;


--DimWarehouse
INSERT INTO DimWarehouse (WarehouseID, WarehouseName, Region)
SELECT DISTINCT
    WarehouseID,
    WarehouseName,
    Region
FROM stg_warehouses;


--DimCarrier
INSERT INTO DimCarrier (CarrierName)
SELECT DISTINCT CarrierName
FROM stg_shipments;


--DimDate
DECLARE @StartDate DATE = '2019-01-01';
DECLARE @EndDate   DATE = '2025-12-31';



;WITH DateSequence AS (
    SELECT @StartDate AS DateValue
    UNION ALL
    SELECT DATEADD(DAY, 1, DateValue)
    FROM DateSequence
    WHERE DateValue < @EndDate
)

INSERT INTO DimDate
SELECT
    CONVERT(INT, FORMAT(DateValue, 'yyyyMMdd')) AS DateKey,
    DateValue AS FullDate,
    DAY(DateValue) AS DayNumber,
    DATENAME(WEEKDAY, DateValue) AS DayName,
    DATEPART(WEEKDAY, DateValue) AS DayOfWeek,
    DATEPART(DAYOFYEAR, DateValue) AS DayOfYear,
    DATEPART(WEEK, DateValue) AS WeekNumber,
    MONTH(DateValue) AS MonthNumber,
    DATENAME(MONTH, DateValue) AS MonthName,
    DATEPART(QUARTER, DateValue) AS QuarterNumber,
    YEAR(DateValue) AS Year,
    FORMAT(DateValue, 'yyyy-MM') AS YearMonth,
    CONCAT(YEAR(DateValue), '-Q', DATEPART(QUARTER, DateValue)) AS YearQuarter,

    CASE WHEN DATENAME(WEEKDAY, DateValue) IN ('Saturday','Sunday')
         THEN 1 ELSE 0 END AS IsWeekend,

    CASE WHEN DAY(DateValue) = 1 THEN 1 ELSE 0 END AS IsMonthStart,
    CASE WHEN DateValue = EOMONTH(DateValue) THEN 1 ELSE 0 END AS IsMonthEnd,

    CASE WHEN DATEPART(DAY, DateValue) = 1
          AND DATEPART(MONTH, DateValue) IN (1,4,7,10)
         THEN 1 ELSE 0 END AS IsQuarterStart,

    CASE WHEN DateValue = EOMONTH(DateValue)
          AND DATEPART(MONTH, DateValue) IN (3,6,9,12)
         THEN 1 ELSE 0 END AS IsQuarterEnd,

    CASE WHEN MONTH(DateValue) = 1 AND DAY(DateValue) = 1
         THEN 1 ELSE 0 END AS IsYearStart,

    CASE WHEN MONTH(DateValue) = 12 AND DAY(DateValue) = 31
         THEN 1 ELSE 0 END AS IsYearEnd

FROM DateSequence
OPTION (MAXRECURSION 0);
