'''
GlobalSupplyChainAnalytics/
│
├── data/
│   ├── raw/
│   └── cleaned/
│
├── scripts/
│   ├── data_generation.py
│   ├── data_cleaning.py
│
├── sql/
│
├── powerbi/
│
└── README.md
'''

'''I intentionally simulated real-world data quality issues such as missing shipment dates,
inconsistent region naming, and negative inventory values, then built a Python cleaning layer
before modeling in SQL Serve'''


import pandas as pd
import numpy as np
import random
from datetime import datetime, timedelta

np.random.seed(42)
random.seed(42)

# --------------------------------------------------
# CONFIGURATION
# --------------------------------------------------

START_DATE = "2023-01-01"
END_DATE = "2024-12-31"

NUM_CUSTOMERS = 500
NUM_PRODUCTS = 100
NUM_SUPPLIERS = 40
NUM_WAREHOUSES = 8
NUM_ORDERS = 20000

REGION_VARIANTS = {
    "North America": ["North America", "NA", "north america"],
    "APAC": ["APAC", "Asia Pacific", "apac"]
}

CARRIERS = ["DHL", "FedEx", "UPS", "Maersk"]

date_range = pd.date_range(start=START_DATE, end=END_DATE)


def generate_random_dates(start_date, end_date, n):
    """
    Generates a list of n random dates between start_date and end_date.
    """
    date_range_days = (end_date - start_date).days
    random_dates = []

    for _ in range(n):
        # Generate a random number of days to add
        random_days = random.randint(0, date_range_days)
        # Generate a random time within that day (optional, can also just use date)
        random_seconds = random.randint(0, 86400) # 86400 seconds in a day
        
        # Calculate the random date
        random_delta = timedelta(days=random_days, seconds=random_seconds)
        new_date = start_date + random_delta
        random_dates.append(new_date)
        
    return random_dates

# --------------------------------------------------
# CUSTOMERS (WITH DUPLICATES & INCONSISTENT REGION)
# --------------------------------------------------

customers = []

for i in range(1, NUM_CUSTOMERS + 1):
    true_region = random.choice(["North America", "APAC"])
    region = random.choice(REGION_VARIANTS[true_region])
    country = random.choice(["Canada", "USA", "South Korea", "Japan"])
    segment = random.choice(["Retail", "Wholesale", "Distributor"])

    customers.append([i, segment, country, region])

# Add duplicate rows intentionally
customers.extend(customers[:10])

df_customers = pd.DataFrame(customers, columns=[
    "CustomerID", "Segment", "Country", "Region"
])

# --------------------------------------------------
# PRODUCTS
# --------------------------------------------------

products = []

for i in range(1, NUM_PRODUCTS + 1):
    category = random.choice(["Electronics", "Food", "Industrial", "Agriculture"])
    price = round(np.random.uniform(10, 500), 2)
    products.append([i, category, price])

df_products = pd.DataFrame(products, columns=[
    "ProductID", "Category", "BasePrice"
])

# --------------------------------------------------
# SUPPLIERS (WITH MISSING LEAD TIME)
# --------------------------------------------------

suppliers = []

for i in range(1, NUM_SUPPLIERS + 1):
    product_id = random.randint(1, NUM_PRODUCTS)
    country = random.choice(["China", "USA", "Vietnam", "Germany"])

    # 10% missing lead time
    if random.random() < 0.1:
        lead_time = None
    else:
        lead_time = random.randint(5, 30)

    suppliers.append([i, product_id, country, lead_time])

df_suppliers = pd.DataFrame(suppliers, columns=[
    "SupplierID", "ProductID", "Country", "LeadTimeDays"
])

# --------------------------------------------------
# WAREHOUSES
# --------------------------------------------------

warehouses = []

for i in range(1, NUM_WAREHOUSES + 1):
    region = random.choice(["North America", "APAC"])
    warehouses.append([i, f"Warehouse_{i}", region])

df_warehouses = pd.DataFrame(warehouses, columns=[
    "WarehouseID", "WarehouseName", "Region"
])

# --------------------------------------------------
# ORDERS (WITH NULL PRICE)
# --------------------------------------------------

orders = []

for i in range(1, NUM_ORDERS + 1):
    order_date = random.choice(date_range)
    customer_id = random.randint(1, NUM_CUSTOMERS)
    product_id = random.randint(1, NUM_PRODUCTS)
    quantity = np.random.poisson(5) + 1

    base_price = df_products.loc[
        df_products["ProductID"] == product_id, "BasePrice"
    ].values[0]

    # 5% missing UnitPrice
    if random.random() < 0.05:
        unit_price = None
    else:
        unit_price = round(base_price * np.random.uniform(0.9, 1.1), 2)

    orders.append([
        i, order_date, customer_id, product_id, quantity, unit_price
    ])

df_orders = pd.DataFrame(orders, columns=[
    "OrderID", "OrderDate", "CustomerID",
    "ProductID", "Quantity", "UnitPrice"
])

# --------------------------------------------------
# SHIPMENTS (WITH MISSING SHIP DATE & BAD DELIVERY)
# --------------------------------------------------

shipments = []

for i, row in df_orders.iterrows():
    shipment_id = i + 1
    warehouse_id = random.randint(1, NUM_WAREHOUSES)

    # 5% missing ShipDate
    if random.random() < 0.05:
        ship_date = None
    else:
        ship_date = row["OrderDate"] + timedelta(days=random.randint(1, 3))

    delivery_days = random.randint(3, 10)

    if ship_date:
        delivery_date = ship_date + timedelta(days=delivery_days)
    else:
        delivery_date = None

    # 3% invalid delivery date (before ship date)
    if ship_date and random.random() < 0.03:
        delivery_date = ship_date - timedelta(days=2)

    carrier = random.choice(CARRIERS)

    shipments.append([
        shipment_id,
        row["OrderID"],
        warehouse_id,
        ship_date,
        delivery_date,
        carrier
    ])

df_shipments = pd.DataFrame(shipments, columns=[
    "ShipmentID", "OrderID", "WarehouseID",
    "ShipDate", "DeliveryDate", "Carrier"
])

# --------------------------------------------------
# INVENTORY (WITH NEGATIVE STOCK)
# --------------------------------------------------

inventory = []

for warehouse_id in range(1, NUM_WAREHOUSES + 1):
    for product_id in range(1, NUM_PRODUCTS + 1):
        stock = random.randint(0, 500)
        reorder_point = random.randint(50, 150)
        inventory.append([
            warehouse_id,
            product_id,
            stock,
            reorder_point
        ])

df_inventory = pd.DataFrame(inventory, columns=[
    "WarehouseID", "ProductID",
    "StockLevel", "ReorderPoint"
])

df_inventory["InventoryDate"] = generate_random_dates(datetime(2023, 1, 1), datetime(2024, 12, 31), 800)

# --------------------------------------------------
# EXPORT RAW FILES
# --------------------------------------------------

df_customers.to_csv("raw_customers.csv", index=False)
df_products.to_csv("raw_products.csv", index=False)
df_suppliers.to_csv("raw_suppliers.csv", index=False)
df_warehouses.to_csv("raw_warehouses.csv", index=False)
df_orders.to_csv("raw_orders.csv", index=False)
df_shipments.to_csv("raw_shipments.csv", index=False)
df_inventory.to_csv("raw_inventory.csv", index=False)

print("✅ Messy raw data generated successfully.")
