import os
import pandas as pd


def main(details_path="outputs/product_id_conflict_details.csv", out_dir="outputs"):
    if not os.path.exists(details_path):
        print(f"{details_path} not found")
        return
    df = pd.read_csv(details_path, parse_dates=["first_order_date", "last_order_date"], low_memory=False)

    agg = df.groupby("product_id").agg(
        total_rows=("number_of_rows", "sum"),
        total_sales=("total_sales", "sum"),
        total_profit=("total_profit", "sum"),
        first_order_date=("first_order_date", "min"),
        last_order_date=("last_order_date", "max"),
    ).reset_index()

    agg["profit_abs"] = agg["total_profit"].abs()

    top_by_rows = agg.sort_values(by=["total_rows", "product_id"], ascending=[False, True]).head(10)
    top_by_profit = agg.sort_values(by=["profit_abs", "product_id"], ascending=[False, True]).head(10)

    # write CSVs
    os.makedirs(out_dir, exist_ok=True)
    top_by_rows.to_csv(os.path.join(out_dir, "top_conflicts_by_rows.csv"), index=False)
    top_by_profit.to_csv(os.path.join(out_dir, "top_conflicts_by_profit.csv"), index=False)

    # print human readable summary
    print("Top conflicts by total rows (product_id, total_rows, total_sales, total_profit):")
    for _, r in top_by_rows.iterrows():
        print(f"{r['product_id']}: rows={int(r['total_rows'])}, sales={r['total_sales']:.2f}, profit={r['total_profit']:.2f}")

    print("\nTop conflicts by absolute profit impact (product_id, total_profit, total_rows):")
    for _, r in top_by_profit.iterrows():
        print(f"{r['product_id']}: profit={r['total_profit']:.2f}, rows={int(r['total_rows'])}, sales={r['total_sales']:.2f}")

    print(f"\nWrote {os.path.join(out_dir, 'top_conflicts_by_rows.csv')} and {os.path.join(out_dir, 'top_conflicts_by_profit.csv')}")


if __name__ == "__main__":
    main()
