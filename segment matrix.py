"""
Customer Analytics Suite — Stage 6: segment priority matrix.

Run after sql/06_segment_summary.sql. One chart, every segment: recency (x),
total estimated CLV (y), bubble size = segment size. This is the "who should
marketing target" chart.

    pip install pandas sqlalchemy psycopg2-binary matplotlib
    python scripts/06_segment_matrix.py
"""

import pandas as pd
import matplotlib.pyplot as plt
from sqlalchemy import create_engine

DB_USER = "postgres"
DB_PASSWORD = "yourpassword"
DB_HOST = "localhost"
DB_PORT = "5432"
DB_NAME = "customer_analytics"

OUTPUT_PATH = "segment_priority_matrix.png"


def main():
    engine = create_engine(
        f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    )
    df = pd.read_sql(
        "SELECT * FROM retail.segment_summary ORDER BY avg_total_estimated_clv DESC;",
        engine,
    )
    engine.dispose()

    fig, ax = plt.subplots(figsize=(11, 8))

    # Bubble size scaled so the smallest segment is still visible and the
    # largest doesn't swallow the plot
    sizes = 300 + 2500 * (df["customers"] / df["customers"].max())

    ax.scatter(
        df["avg_recency_days"],
        df["avg_total_estimated_clv"],
        s=sizes,
        alpha=0.6,
        c=range(len(df)),
        cmap="tab10",
        edgecolors="black",
        linewidths=0.8,
    )

    for _, row in df.iterrows():
        ax.annotate(
            f"{row['rfm_segment']}\n({row['customers']} customers)",
            (row["avg_recency_days"], row["avg_total_estimated_clv"]),
            ha="center", va="center", fontsize=8,
        )

    ax.set_xlabel("Average days since last purchase (lower = more recently active)")
    ax.set_ylabel("Average total estimated CLV ($)")
    ax.set_title("Segment Priority Matrix: value vs. recency, sized by segment size")
    ax.invert_xaxis()  # so "more engaged" reads toward the right of the chart
    ax.grid(alpha=0.3)

    plt.tight_layout()
    plt.savefig(OUTPUT_PATH, dpi=150)
    print(f"Saved {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
