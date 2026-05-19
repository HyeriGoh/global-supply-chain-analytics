import pandas as pd
import numpy as np
from pathlib import Path

# --------------------------------------------------
# CONFIGURATION
# --------------------------------------------------

RAW_PATH = Path("data/raw")
CLEAN_PATH = Path("data/cleaned")
CLEAN_PATH.mkdir(parents=True, exist_ok=True)

SLA_DAYS_NA = 7
SLA_DAYS_APAC = 12

# --------------------------------------------------
# HELPER FUNCTIONS
# --------------------------------------------------

def standardize_region(region):
    """
    Standardizes region naming inconsistencies.
    """
    if pd.isna(region):
        return None

    region = region.strip().lower()

    if region in ["na", "north america"]:
        return "North America"
    elif region in ["apac", "asia pacific"]:
        return "APAC"
    else:
        return region.title()


def calculate_on_time_flag(row):
    """
    Determines if shipment met SLA threshold.
    """
    if pd.isna(row["DeliveryDays"]) or pd.isna(row["Region"]):
        return 0

    if row["Region"] == "North America":
        return 1 if row["DeliveryDays"] <= SLA_DAYS_NA else 0
    elif row["Region"] == "APAC":
        return 1 if row["DeliveryDays"] <= SLA_DAYS_APAC else 0

    return 0


def data_quality_summary(df, table_name):
    """
    Generates simple data quality metrics.
    """
    summary = {
        "Table": table_name,
        "RowCount": len(df),
        "NullCount": df.isnull().sum().sum(),
        "DuplicateRows": df.duplicated().sum()
    }
    return summary


# --------------------------------------------------
# LOAD RAW DATA
# --------------------------------------------------

df_customers = pd.read_csv(RAW_PATH / "raw_customers.csv")
df_products = pd.read_csv(RAW_PATH / "raw_products.csv")
df_suppliers = pd.read_csv(RAW_PATH / "raw_suppliers.csv")
df_warehouses = pd.read_csv(RAW_PATH / "raw_warehouses.csv")
df_orders = pd.read_csv(RAW_PATH / "raw_orders.csv", parse_dates=["OrderDate"])
df_shipments = pd.read_csv(
    RAW_PATH / "raw_shipments.csv",
    parse_dates=["ShipDate", "DeliveryDate"]
)
df_inventory = pd.read_csv(RAW_PATH / "raw_inventory.csv")

quality_reports = []

# --------------------------------------------------
# CLEAN CUSTOMERS
# --------------------------------------------------

df_customers["Region"] = df_customers["Region"].apply(standardize_region)

df_customers.loc[
    df_customers["Country"].isin(["Canada", "USA"]),
    "Region"
] = "North America"

df_customers.loc[
    ~df_customers["Country"].isin(["Canada", "USA"]),
    "Region"
] = "APAC"

df_customers = df_customers.drop_duplicates(subset=["CustomerID"])

quality_reports.append(data_quality_summary(df_customers, "Customers"))

# --------------------------------------------------
# CLEAN SUPPLIERS
# --------------------------------------------------

# Fill missing LeadTimeDays with median
median_lead_time = df_suppliers["LeadTimeDays"].median()
df_suppliers["LeadTimeDays"] = df_suppliers["LeadTimeDays"].fillna(median_lead_time)

df_suppliers["LeadTimeDays"] = df_suppliers["LeadTimeDays"].astype("Int64")

quality_reports.append(data_quality_summary(df_suppliers, "Suppliers"))

# --------------------------------------------------
# CLEAN ORDERS
# --------------------------------------------------

# Fill missing UnitPrice with product BasePrice
df_orders = df_orders.merge(
    df_products[["ProductID", "BasePrice"]],
    on="ProductID",
    how="left"
)

df_orders["UnitPrice"] = df_orders["UnitPrice"].fillna(df_orders["BasePrice"])

# Create Revenue column
df_orders["Revenue"] = df_orders["Quantity"] * df_orders["UnitPrice"]

df_orders = df_orders.drop(columns=["BasePrice"])

quality_reports.append(data_quality_summary(df_orders, "Orders"))

# --------------------------------------------------
# CLEAN SHIPMENTS
# --------------------------------------------------

# Fill missing ShipDate using OrderDate + 2 days default
df_shipments = df_shipments.merge(
    df_orders[["OrderID", "OrderDate"]],
    on="OrderID",
    how="left"
)

df_shipments["ShipDate"] = df_shipments["ShipDate"].fillna(
    df_shipments["OrderDate"] + pd.Timedelta(days=2)
)


# Fill missing DeliveryDays and DeliveryDate
df_shipments["DeliveryDate"] = df_shipments["DeliveryDate"].fillna(df_shipments["ShipDate"] + pd.Timedelta(days=5))


# Fix invalid DeliveryDate (earlier than ShipDate)
df_shipments.loc[
    df_shipments["DeliveryDate"] < df_shipments["ShipDate"],
    "DeliveryDate"
] = df_shipments["ShipDate"] + pd.Timedelta(days=3)

# Calculate DeliveryDays
df_shipments["DeliveryDays"] = (
    df_shipments["DeliveryDate"] - df_shipments["ShipDate"]
).dt.days

df_shipments["DeliveryDays"] = df_shipments["DeliveryDays"].astype("Int64")

# Attach customer region
df_shipments = df_shipments.merge(
    df_orders[["OrderID", "CustomerID"]],
    on="OrderID",
    how="left"
).merge(
    df_customers[["CustomerID", "Region"]],
    on="CustomerID",
    how="left"
)

# Calculate OnTimeFlag
df_shipments["OnTimeFlag"] = df_shipments.apply(
    calculate_on_time_flag,
    axis=1
)

df_shipments = df_shipments.drop(columns=["OrderDate"])

quality_reports.append(data_quality_summary(df_shipments, "Shipments"))

# --------------------------------------------------
# CLEAN INVENTORY
# --------------------------------------------------

# Remove negative stock
df_inventory["StockLevel"] = df_inventory["StockLevel"].clip(lower=0)

df_inventory["InventoryDate"] = pd.to_datetime(df_inventory["InventoryDate"])

quality_reports.append(data_quality_summary(df_inventory, "Inventory"))

# --------------------------------------------------
# EXPORT CLEANED DATA
# --------------------------------------------------

df_customers.to_csv(CLEAN_PATH / "clean_customers.csv", index=False)
df_products.to_csv(CLEAN_PATH / "clean_products.csv", index=False)
df_suppliers.to_csv(CLEAN_PATH / "clean_suppliers.csv", index=False)
df_warehouses.to_csv(CLEAN_PATH / "clean_warehouses.csv", index=False)
df_orders.to_csv(CLEAN_PATH / "clean_orders.csv", index=False)
df_shipments.to_csv(CLEAN_PATH / "clean_shipments.csv", index=False)
df_inventory.to_csv(CLEAN_PATH / "clean_inventory.csv", index=False)

# --------------------------------------------------
# EXPORT DATA QUALITY REPORT
# --------------------------------------------------

df_quality = pd.DataFrame(quality_reports)
df_quality.to_csv(CLEAN_PATH / "data_quality_report.csv", index=False)

print("✅ Data cleaning completed successfully.")
print("📊 Data quality report generated.")
