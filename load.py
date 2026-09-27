import pandas as pd
from sqlalchemy import create_engine

# ---- connection settings — edit for your local Postgres ----
DB_USER = "postgres"
DB_PASSWORD = "pass1234"
DB_HOST = "localhost"
DB_PORT = "5432"
DB_NAME = "customer_analytics"

DATA_PATH = "data/online_retail_II.xlsx"

# UCI has used slightly different header names across versions of this dataset
# ("InvoiceNo" vs "Invoice", "UnitPrice" vs "Price", "CustomerID" vs "Customer ID").
# Normalizing to lowercase/no-spaces first means this map covers both.
RENAME_MAP = {
    "invoiceno": "invoice",
    "invoice": "invoice",
    "stockcode": "stock_code",
    "description": "description",
    "quantity": "quantity",
    "invoicedate": "invoice_date",
    "unitprice": "price",
    "price": "price",
    "customerid": "customer_id",
    "customer_id": "customer_id",
    "country": "country",
}

EXPECTED_COLUMNS = [
    "invoice", "stock_code", "description", "quantity",
    "invoice_date", "price", "customer_id", "country",
]


def load_raw_data(path: str) -> pd.DataFrame:
    print(f"Reading {path} (both sheets, ~1M rows total — this can take a minute)...")
    sheets = pd.read_excel(path, sheet_name=None)  # dict of {sheet_name: DataFrame}
    df = pd.concat(sheets.values(), ignore_index=True)

    df.columns = [c.strip().lower().replace(" ", "") for c in df.columns]
    df = df.rename(columns=RENAME_MAP)
    df = df[EXPECTED_COLUMNS]

    df["customer_id"] = df["customer_id"].astype("Int64")   # nullable int — ~25% are missing
    df["invoice_date"] = pd.to_datetime(df["invoice_date"])

    return df


def main():
    df = load_raw_data(DATA_PATH)

    n_total = len(df)
    n_missing_customer = int(df["customer_id"].isna().sum())
    n_cancellations = int(df["invoice"].astype(str).str.startswith("C").sum())

    print(f"Total rows:            {n_total:,}")
    print(f"Missing customer_id:   {n_missing_customer:,} ({n_missing_customer / n_total:.1%})")
    print(f"Cancellation invoices: {n_cancellations:,}")
    print("(We'll handle both properly in Stage 2 — cleaning. Loading as-is for now.)")

    engine = create_engine(
        f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    )

    print("Writing to retail.raw_transactions ...")
    df.to_sql(
        "raw_transactions",
        engine,
        schema="retail",
        if_exists="append",
        index=False,
        chunksize=20000,
        method="multi",
    )
    engine.dispose()
    print("Done — raw data is loaded.")


if __name__ == "__main__":
    main()