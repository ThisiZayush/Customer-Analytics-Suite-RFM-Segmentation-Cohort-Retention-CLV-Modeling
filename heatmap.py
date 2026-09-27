"""
Customer Analytics Suite — Stage 4: cohort retention heatmap.

Run after sql/04_cohort_retention.sql. Pulls the (small, pre-aggregated)
retention table from Postgres, pivots it into a cohort x period matrix,
and saves it as a heatmap PNG.

    pip install pandas sqlalchemy psycopg2-binary matplotlib seaborn
    python scripts/04_cohort_heatmap.py
"""

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from sqlalchemy import create_engine

DB_USER = "postgres"
DB_PASSWORD = "pass1234"
DB_HOST = "localhost"
DB_PORT = "5432"
DB_NAME = "customer_analytics"

OUTPUT_PATH = "cohort_retention_heatmap.png"


def main():
    engine = create_engine(
        f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    )
    df = pd.read_sql(
        "SELECT * FROM retail.cohort_retention ORDER BY cohort_month, period_number;",
        engine,
    )
    engine.dispose()

    # Pivot to a cohort_month x period_number matrix of retention %.
    # Recent cohorts haven't lived long enough to have late periods yet —
    # those cells come back as NaN, which is expected, not a bug.
    matrix = df.pivot(index="cohort_month", columns="period_number", values="retention_pct")

    # Label each row with cohort size, e.g. "2010-01 (n=417)"
    cohort_sizes = df.drop_duplicates("cohort_month").set_index("cohort_month")["cohort_size"]
    y_labels = [f"{d.strftime('%Y-%m')} (n={cohort_sizes[d]})" for d in matrix.index]

    plt.figure(figsize=(16, 10))
    sns.heatmap(
        matrix,
        annot=True,
        fmt=".0f",
        cmap="YlGnBu",
        vmin=0,
        vmax=100,
        mask=matrix.isnull(),
        yticklabels=y_labels,
        cbar_kws={"label": "% of cohort still active"},
    )
    plt.title("Monthly Cohort Retention (%)")
    plt.xlabel("Months since first purchase")
    plt.ylabel("Acquisition cohort")
    plt.tight_layout()
    plt.savefig(OUTPUT_PATH, dpi=150)
    print(f"Saved {OUTPUT_PATH}")

    # Headline numbers worth quoting in a write-up
    for period in (1, 3, 6):
        if period in matrix.columns:
            print(f"Average retention at month {period}: {matrix[period].mean():.1f}%")


if __name__ == "__main__":
    main()