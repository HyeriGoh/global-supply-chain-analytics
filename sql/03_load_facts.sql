USE SupplyChainBI;
GO

-- FactOrders
INSERT INTO FactOrders (
    OrderID,
    OrderDateKey,
    CustomerKey,
    ProductKey,
    Quantity,
    UnitPrice,
    Revenue
)
SELECT
    o.OrderID,
    CONVERT(INT, FORMAT(o.OrderDate, 'yyyyMMdd')) AS OrderDateKey,
    dc.CustomerKey,
    dp.ProductKey,
    o.Quantity,
    o.UnitPrice,
    o.Revenue
FROM stg_orders o
INNER JOIN DimCustomer dc
    ON o.CustomerID = dc.CustomerID
INNER JOIN DimProduct dp
    ON o.ProductID = dp.ProductID;


--FactShipments
INSERT INTO FactShipments (
    ShipmentID,
    OrderKey,
    ShipDateKey,
    DeliveryDateKey,
    WarehouseKey,
    CarrierKey,
    DeliveryDays,
    OnTimeFlag
)
SELECT
    s.ShipmentID,
    fo.OrderKey,
    CONVERT(INT, FORMAT(s.ShipDate, 'yyyyMMdd')) AS ShipDateKey,
    CONVERT(INT, FORMAT(s.DeliveryDate, 'yyyyMMdd')) AS DeliveryDateKey,
    dw.WarehouseKey,
    dcarr.CarrierKey,
    s.DeliveryDays,
    s.OnTimeFlag
FROM stg_shipments s
INNER JOIN FactOrders fo
    ON s.OrderID = fo.OrderID
INNER JOIN DimWarehouse dw
    ON s.WarehouseID = dw.WarehouseID
INNER JOIN DimCarrier dcarr
    ON s.CarrierName = dcarr.CarrierName;


--FactInventory
INSERT INTO FactInventory (
    DateKey,
    ProductKey,
    WarehouseKey,
	SupplierKey,
    StockQuantity,
    ReorderLevel
)
SELECT
    dd.DateKey,
    dp.ProductKey,
    dw.WarehouseKey,
	ds.SupplierKey,
    i.StockQuantity,
    i.ReorderLevel
FROM stg_inventory i
INNER JOIN DimProduct dp
    ON i.ProductID = dp.ProductID
INNER JOIN DimWarehouse dw
    ON i.WarehouseID = dw.WarehouseID
INNER JOIN DimSupplier ds
    ON dp.ProductID = ds.ProductID
INNER JOIN DimDate dd
	ON i.InventoryDate = dd.FullDate;

/*
DimDate
DimCustomer
DimProduct
DimWarehouse
DimCarrier
DimSupplier

FactOrders
FactShipments
FactInventory
*/
