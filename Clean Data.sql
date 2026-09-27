
DROP TABLE IF EXISTS retail.clean_lines;

CREATE TABLE retail.clean_lines AS
WITH deduped AS (
    -- Collapse exact duplicate rows — a data-loading artifact in this dataset,
    -- not the same as a customer legitimately buying 2 units (that's one row
    -- with quantity = 2, not two identical rows).
    SELECT DISTINCT
        invoice, stock_code, description, quantity,
        invoice_date, price, customer_id, country
    FROM retail.raw_transactions
)
SELECT
    invoice,
    stock_code,
    description,
    quantity,
    invoice_date,
    price,
    customer_id,
    country,
    (invoice LIKE 'C%')  AS is_cancellation,
    (quantity * price)   AS line_revenue
FROM deduped
WHERE customer_id IS NOT NULL     -- can't attribute to a customer -> useless for RFM/CLV/cohorts
  AND price > 0                   -- drop zero/negative-price rows (samples, price-correction errors)
  AND stock_code ~ '^[0-9]';      -- keep real products only; drops POST, D, DOT, M, BANK CHARGES, etc.

CREATE INDEX idx_clean_customer_id  ON retail.clean_lines (customer_id);
CREATE INDEX idx_clean_invoice_date ON retail.clean_lines (invoice_date);
CREATE INDEX idx_clean_invoice      ON retail.clean_lines (invoice);

COMMENT ON TABLE retail.clean_lines IS
  'One row per invoice line, filtered to attributable, real-product transactions. '
  'Cancellations (is_cancellation = true, negative quantity) are KEPT so that summed '
  'line_revenue reflects true net spend per customer. Exclude is_cancellation = true '
  'invoices when counting purchase FREQUENCY in Stage 3 — a return is not a new order.';
