import argparse
import os
import logging
from datetime import datetime

import pandas as pd


logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")


def snake_case(s: str) -> str:
    return (
        s.strip()
        .lower()
        .replace(" ", "_")
        .replace("-", "_")
        .replace("__", "_")
        .replace("%", "_pct")
    )


def normalize_columns(df: pd.DataFrame) -> pd.DataFrame:
    df.columns = [snake_case(c) for c in df.columns]
    return df


def parse_dates(df: pd.DataFrame, cols, dayfirst=True):
    for c in cols:
        if c in df.columns:
            df[c] = pd.to_datetime(df[c], errors="coerce", dayfirst=dayfirst)
    return df


def prepare_dimensions(df: pd.DataFrame, out_dir: str):
    # Date dimension: full continuous calendar from min to max fact date
    date_cols = [c for c in ("order_date", "ship_date") if c in df.columns]

    if not date_cols:
        raise ValueError("No order_date or ship_date column found. Cannot create dim_date.")

    all_dates = pd.concat([df[c].dropna() for c in date_cols], ignore_index=True)

    if all_dates.empty:
        raise ValueError("All order_date and ship_date values are null after parsing. Check date parsing.")

    start_date = all_dates.min().normalize()
    end_date = all_dates.max().normalize()

    logging.info("Date range detected: %s to %s", start_date.date(), end_date.date())
    logging.info("Distinct parsed dates found: %d", all_dates.dt.normalize().nunique())

    full_calendar = pd.date_range(start=start_date, end=end_date, freq="D")

    dim_date = pd.DataFrame({"date": full_calendar})
    dim_date["date_key"] = dim_date["date"].dt.strftime("%Y%m%d").astype(int)
    dim_date["year"] = dim_date["date"].dt.year
    dim_date["quarter"] = dim_date["date"].dt.to_period("Q").astype(str)
    dim_date["month"] = dim_date["date"].dt.month
    dim_date["month_name"] = dim_date["date"].dt.month_name()
    dim_date["day"] = dim_date["date"].dt.day
    dim_date["weekday"] = dim_date["date"].dt.day_name()

    dim_date.to_csv(os.path.join(out_dir, "dim_date.csv"), index=False)
    logging.info("Written dim_date (%d rows)", len(dim_date))

    # Customer dimension: only customer-level attributes (no geography)
    cust_cols = [c for c in ["customer_id", "customer_name", "segment"] if c in df.columns]
    if cust_cols:
        dim_customer = df[cust_cols].drop_duplicates(subset=["customer_id"]).reset_index(drop=True)
        dim_customer["customer_key"] = dim_customer.index + 1
        dim_customer.to_csv(os.path.join(out_dir, "dim_customer.csv"), index=False)
        logging.info("Written dim_customer (%d rows)", len(dim_customer))

    # Product dimension — check product_id consistency before creating keys
    prod_cols = [c for c in ["product_id", "product_name", "category", "sub_category"] if c in df.columns]

    dim_product = df[prod_cols].drop_duplicates().reset_index(drop=True)
    dim_product["product_key"] = dim_product.index + 1
    dim_product.to_csv(os.path.join(out_dir, "dim_product.csv"), index=False)
    logging.info("Written dim_product (%d rows)", len(dim_product))

    # Geography dimension
    geo_cols = [c for c in ["country", "region", "state", "city", "postal_code"] if c in df.columns]
    if geo_cols:
        dim_geography = df[geo_cols].drop_duplicates().reset_index(drop=True)
        dim_geography["geography_key"] = dim_geography.index + 1
        dim_geography.to_csv(os.path.join(out_dir, "dim_geography.csv"), index=False)
        logging.info("Written dim_geography (%d rows)", len(dim_geography))

    # Ship mode dimension
    if "ship_mode" in df.columns:
        dim_ship_mode = pd.DataFrame({"ship_mode": df["ship_mode"].dropna().unique()})
        dim_ship_mode["ship_mode_key"] = dim_ship_mode.index + 1
        dim_ship_mode.to_csv(os.path.join(out_dir, "dim_ship_mode.csv"), index=False)
        logging.info("Written dim_ship_mode (%d rows)", len(dim_ship_mode))

    return dim_date, locals().get("dim_customer"), locals().get("dim_product"), locals().get("dim_geography"), locals().get("dim_ship_mode")


def build_fact_table(df: pd.DataFrame, dims: tuple, out_dir: str):
    dim_date, dim_customer, dim_product, dim_geography, dim_ship_mode = dims

    fact = df.copy()

    # Map order_date and ship_date to date_key
    if "order_date" in fact.columns:
        fact = fact.merge(dim_date[["date", "date_key"]].rename(columns={"date": "order_date"}), on="order_date", how="left")
        fact = fact.rename(columns={"date_key": "order_date_key"})
    if "ship_date" in fact.columns:
        fact = fact.merge(dim_date[["date", "date_key"]].rename(columns={"date": "ship_date"}), on="ship_date", how="left")
        fact = fact.rename(columns={"date_key": "ship_date_key"})

    if dim_customer is not None and "customer_id" in fact.columns:
        fact = fact.merge(dim_customer[["customer_id", "customer_key"]], on="customer_id", how="left")
    if dim_product is not None and "product_id" in fact.columns:
        product_merge_cols = [c for c in ["product_id", "product_name", "category", "sub_category"] if c in fact.columns and c in dim_product.columns]
        fact = fact.merge(
            dim_product[product_merge_cols + ["product_key"]],
            on=product_merge_cols,
            how="left"
        )
    if dim_geography is not None and all(c in fact.columns for c in ["country", "region"]):
        geo_cols = [c for c in ["country", "region", "state", "city", "postal_code"] if c in fact.columns]
        fact = fact.merge(dim_geography[geo_cols + ["geography_key"]], on=geo_cols, how="left")
    if dim_ship_mode is not None and "ship_mode" in fact.columns:
        fact = fact.merge(dim_ship_mode[["ship_mode", "ship_mode_key"]], on="ship_mode", how="left")

    # Keep core measure columns if present
    measures = [c for c in ["sales", "quantity", "discount", "profit"] if c in fact.columns]
    keys = [c for c in ["order_id", "order_date_key", "ship_date_key", "customer_key", "product_key", "geography_key", "ship_mode_key"] if c in fact.columns]

    selected = [c for c in keys + measures if c in fact.columns]
    if not selected:
        # Fallback: keep everything
        fact.to_csv(os.path.join(out_dir, "fact_sales.csv"), index=False)
        logging.info("Written fact_sales (fallback, full table) %d rows", len(fact))
        return

    fact_sales = fact[selected].copy()
    # add a stable row-level surrogate key for the fact table
    fact_sales.insert(0, "sales_key", range(1, len(fact_sales) + 1))
    fact_sales.to_csv(os.path.join(out_dir, "fact_sales.csv"), index=False)
    logging.info("Written fact_sales (%d rows, %d columns)", len(fact_sales), len(fact_sales.columns))


def clean_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    # Trim strings
    for c in df.select_dtypes(include=["string", "object"]).columns:
        df[c] = df[c].astype(str).str.strip()

    # Lowercase column names already handled

    # Convert numeric columns
    for c in ["sales", "profit", "discount"]:
        if c in df.columns:
            df[c] = pd.to_numeric(df[c], errors="coerce")
    if "quantity" in df.columns:
        df["quantity"] = pd.to_numeric(df["quantity"], errors="coerce").fillna(0).astype(int)

    # Drop fully empty rows
    df = df.dropna(how="all")

    # Drop duplicate order lines if exact duplicates
    df = df.drop_duplicates()

    return df


def main():
    parser = argparse.ArgumentParser(description="Prepare Global Superstore dataset into star schema CSVs")
    parser.add_argument("--input", "-i", default="Global Superstore.csv", help="Path to the Global Superstore CSV file")
    parser.add_argument("--out", "-o", default="outputs", help="Output directory for generated CSVs")
    args = parser.parse_args()

    os.makedirs(args.out, exist_ok=True)

    logging.info("Loading %s", args.input)
    df = pd.read_csv(args.input, encoding="utf-8", low_memory=False)

    df = normalize_columns(df)
    df = parse_dates(df, ["order_date", "ship_date"], dayfirst=True)
    for c in ["order_date", "ship_date"]:
        if c in df.columns:
            df[c] = df[c].dt.normalize()
    df = clean_dataframe(df)

    dims = prepare_dimensions(df, args.out)
    build_fact_table(df, dims, args.out)

    logging.info("Data prep finished. Outputs saved in %s", args.out)


if __name__ == "__main__":
    main()
