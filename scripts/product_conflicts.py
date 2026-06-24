import os
import pandas as pd


def snake_case(s: str) -> str:
    return (
        s.strip()
        .lower()
        .replace(" ", "_")
        .replace("-", "_")
        .replace("__", "_")
        .replace("%", "_pct")
    )

def main(input_path="Global Superstore.csv", out_dir="outputs"):
    os.makedirs(out_dir, exist_ok=True)
    df = pd.read_csv(input_path, encoding="utf-8", low_memory=False)
    df.columns = [snake_case(c) for c in df.columns]
    if "order_date" in df.columns:
        df["order_date"] = pd.to_datetime(df["order_date"], errors="coerce")

    # ensure numeric
    for c in ["sales", "profit"]:
        if c in df.columns:
            df[c] = pd.to_numeric(df[c], errors="coerce").fillna(0)

    cols_to_check = [c for c in ["product_name", "category", "sub_category"] if c in df.columns]
    if "product_id" not in df.columns or not cols_to_check:
        print("No product_id or product fields found; nothing to do.")
        return

    prod_group = df.groupby("product_id")[cols_to_check].nunique()
    conflicts_idx = prod_group[(prod_group[cols_to_check] > 1).any(axis=1)].index.tolist()

    if not conflicts_idx:
        print("No conflicting product_id found.")
        return

    # compute total rows per product_id and pick top 10 by total rows
    counts = df.groupby("product_id").size().rename("total_rows")
    conflicts_counts = counts.loc[conflicts_idx].sort_values(ascending=False)
    top10 = conflicts_counts.head(10).index.tolist()

    records = []
    for pid in sorted(top10):
        sub = df[df["product_id"] == pid]
        agg = (
            sub.groupby([c for c in ["product_name", "category", "sub_category"] if c in sub.columns])
            .agg(
                number_of_rows=("product_id", "size"),
                total_sales=("sales", "sum") if "sales" in sub.columns else ("product_id", "size"),
                total_profit=("profit", "sum") if "profit" in sub.columns else ("product_id", "size"),
                first_order_date=("order_date", "min") if "order_date" in sub.columns else ("product_id", "size"),
                last_order_date=("order_date", "max") if "order_date" in sub.columns else ("product_id", "size"),
            )
            .reset_index()
        )
        for _, row in agg.iterrows():
            records.append({
                "product_id": pid,
                "product_name": row.get("product_name", ""),
                "category": row.get("category", ""),
                "sub_category": row.get("sub_category", ""),
                "number_of_rows": int(row["number_of_rows"]),
                "total_sales": float(row.get("total_sales", 0) or 0),
                "total_profit": float(row.get("total_profit", 0) or 0),
                "first_order_date": pd.to_datetime(row.get("first_order_date")).strftime("%Y-%m-%d") if pd.notna(row.get("first_order_date")) else "",
                "last_order_date": pd.to_datetime(row.get("last_order_date")).strftime("%Y-%m-%d") if pd.notna(row.get("last_order_date")) else "",
            })

    out_df = pd.DataFrame.from_records(records)
    # sort by product_id and number_of_rows desc
    out_df = out_df.sort_values(by=["product_id", "number_of_rows"], ascending=[True, False])
    out_path = os.path.join(out_dir, "product_id_conflict_details.csv")
    out_df.to_csv(out_path, index=False)
    print(f"Wrote {out_path} ({len(out_df)} rows)")


if __name__ == "__main__":
    main()
