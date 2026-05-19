USE master;
GO

ALTER DATABASE SupplyChainBI
SET SINGLE_USER
WITH ROLLBACK IMMEDIATE;
GO

DROP DATABASE SupplyChainBI;
GO


-- Create Database
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'SupplyChainBI')
BEGIN
    CREATE DATABASE SupplyChainBI;
END
GO

USE SupplyChainBI;
GO


-- Drop if exists
IF OBJECT_ID('DimDate', 'U') IS NOT NULL DROP TABLE DimDate;
IF OBJECT_ID('DimCustomer') IS NOT NULL DROP TABLE DimCustomer;
IF OBJECT_ID('DimProduct') IS NOT NULL DROP TABLE DimProduct;
IF OBJECT_ID('DimSupplier') IS NOT NULL DROP TABLE DimSupplier;
IF OBJECT_ID('DimWarehouse') IS NOT NULL DROP TABLE DimWarehouse;
IF OBJECT_ID('DimCarrier') IS NOT NULL DROP TABLE DimCarrier;
IF OBJECT_ID('FactOrders') IS NOT NULL DROP TABLE FactOrders;
IF OBJECT_ID('FactShipments') IS NOT NULL DROP TABLE FactShipments;
IF OBJECT_ID('FactInventory') IS NOT NULL DROP TABLE FactInventory;

GO



CREATE TABLE DimCustomer (
    CustomerKey INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL,
    Segment VARCHAR(50),
    Country VARCHAR(50),
    Region VARCHAR(50)
);


CREATE TABLE DimProduct (
    ProductKey INT IDENTITY(1,1) PRIMARY KEY,
    ProductID INT NOT NULL,
    Category VARCHAR(50),
    BasePrice DECIMAL(18,2)
);


CREATE TABLE DimSupplier (
    SupplierKey INT IDENTITY(1,1) PRIMARY KEY,
    SupplierID INT NOT NULL,
    ProductID INT NOT NULL,
    Country VARCHAR(50),
    LeadTimeDays INT
);


CREATE TABLE DimWarehouse (
    WarehouseKey INT IDENTITY(1,1) PRIMARY KEY,
    WarehouseID INT NOT NULL,
    WarehouseName VARCHAR(100),
    Region VARCHAR(50)
);


CREATE TABLE DimCarrier (
    CarrierKey INT IDENTITY(1,1) PRIMARY KEY,
    CarrierName VARCHAR(50)
);


CREATE TABLE DimDate (
    DateKey INT PRIMARY KEY,              -- YYYYMMDD
    FullDate DATE NOT NULL,
    DayNumber INT NOT NULL,
    DayName VARCHAR(20) NOT NULL,
    DayOfWeek INT NOT NULL,
    DayOfYear INT NOT NULL,
    WeekNumber INT NOT NULL,
    MonthNumber INT NOT NULL,
    MonthName VARCHAR(20) NOT NULL,
    QuarterNumber INT NOT NULL,
    Year INT NOT NULL,
    YearMonth VARCHAR(7) NOT NULL,        -- 2024-01
    YearQuarter VARCHAR(7) NOT NULL,      -- 2024-Q1
    IsWeekend BIT NOT NULL,
    IsMonthStart BIT NOT NULL,
    IsMonthEnd BIT NOT NULL,
    IsQuarterStart BIT NOT NULL,
    IsQuarterEnd BIT NOT NULL,
    IsYearStart BIT NOT NULL,
    IsYearEnd BIT NOT NULL
);


CREATE TABLE FactOrders (
    OrderKey INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT NOT NULL,
    OrderDateKey INT NOT NULL,
    CustomerKey INT NOT NULL,
    ProductKey INT NOT NULL,
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(18,2) NOT NULL,
    Revenue DECIMAL(18,2) NOT NULL,

    CONSTRAINT FK_FactOrders_Date
        FOREIGN KEY (OrderDateKey) REFERENCES DimDate(DateKey),

    CONSTRAINT FK_FactOrders_Customer
        FOREIGN KEY (CustomerKey) REFERENCES DimCustomer(CustomerKey),

    CONSTRAINT FK_FactOrders_Product
        FOREIGN KEY (ProductKey) REFERENCES DimProduct(ProductKey)
);


CREATE TABLE FactShipments (
    ShipmentKey INT IDENTITY(1,1) PRIMARY KEY,
    ShipmentID INT NOT NULL,
    OrderKey INT NOT NULL,
    ShipDateKey INT NOT NULL,
    DeliveryDateKey INT NOT NULL,
    WarehouseKey INT NOT NULL,
    CarrierKey INT NOT NULL,
    DeliveryDays INT,
    OnTimeFlag BIT,

    CONSTRAINT FK_FactShipments_Order
        FOREIGN KEY (OrderKey) REFERENCES FactOrders(OrderKey),

    CONSTRAINT FK_FactShipments_ShipDate
        FOREIGN KEY (ShipDateKey) REFERENCES DimDate(DateKey),

    CONSTRAINT FK_FactShipments_DeliveryDate
        FOREIGN KEY (DeliveryDateKey) REFERENCES DimDate(DateKey),

    CONSTRAINT FK_FactShipments_Warehouse
        FOREIGN KEY (WarehouseKey) REFERENCES DimWarehouse(WarehouseKey),

    CONSTRAINT FK_FactShipments_Carrier
        FOREIGN KEY (CarrierKey) REFERENCES DimCarrier(CarrierKey)
);



CREATE TABLE FactInventory (
    InventoryKey INT IDENTITY(1,1) PRIMARY KEY,
    DateKey INT NOT NULL,
    ProductKey INT NOT NULL,
    WarehouseKey INT NOT NULL,
	SupplierKey INT NOT NULL,
    StockQuantity INT NOT NULL,
    ReorderLevel INT,
    
    CONSTRAINT FK_FactInventory_Date
        FOREIGN KEY (DateKey) REFERENCES DimDate(DateKey),

    CONSTRAINT FK_FactInventory_Product
        FOREIGN KEY (ProductKey) REFERENCES DimProduct(ProductKey),

    CONSTRAINT FK_FactInventory_Warehouse
        FOREIGN KEY (WarehouseKey) REFERENCES DimWarehouse(WarehouseKey),

	CONSTRAINT FK_FactInventory_Supplier
		FOREIGN KEY (SupplierKey) REFERENCES DimSupplier(SupplierKey)
);



-- FactOrders Indexes
CREATE INDEX IX_FactOrders_DateKey ON FactOrders(OrderDateKey);
CREATE INDEX IX_FactOrders_CustomerKey ON FactOrders(CustomerKey);
CREATE INDEX IX_FactOrders_ProductKey ON FactOrders(ProductKey);

-- FactShipments Indexes
CREATE INDEX IX_FactShipments_OrderKey ON FactShipments(OrderKey);
CREATE INDEX IX_FactShipments_ShipDateKey ON FactShipments(ShipDateKey);
CREATE INDEX IX_FactShipments_WarehouseKey ON FactShipments(WarehouseKey);


/*
Why Inventory Is Different

Orders and Shipments are: Transactional events/Occur at a specific moment

Inventory is: A snapshot/Represents stock level at a point in time/Usually tracked daily or monthly

That means:
 It should be a FactSnapshot table
 NOT mixed into FactOrders
*/