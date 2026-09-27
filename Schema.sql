
CREATE SCHEMA IF NOT EXISTS retail;

DROP TABLE IF EXISTS retail.raw_transactions;

CREATE TABLE retail.raw_transactions (
    invoice         VARCHAR(20),
    stock_code      VARCHAR(20),
    description     TEXT,
    quantity        INTEGER,
    invoice_date    TIMESTAMP,
    price           NUMERIC(12, 2),
    customer_id     INTEGER,
    country         VARCHAR(50)
);

-- Indexes we'll lean on heavily for RFM / cohort queries later
CREATE INDEX idx_raw_customer_id  ON retail.raw_transactions (customer_id);
CREATE INDEX idx_raw_invoice_date ON retail.raw_transactions (invoice_date);
CREATE INDEX idx_raw_invoice      ON retail.raw_transactions (invoice);

COMMENT ON TABLE retail.raw_transactions IS
  'One row per invoice line item, loaded as-is from the Online Retail II source file. '
  'Not yet cleaned — cancellations, missing customer_id, and non-product stock codes '
  '(postage, bank charges, manual adjustments) are all still present. Cleaned in Stage 2.';
