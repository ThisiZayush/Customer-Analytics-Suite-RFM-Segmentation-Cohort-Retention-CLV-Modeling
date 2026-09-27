-- Dataset-wide retention curve, pooled by period (not simple-averaged across
-- cohorts, so small/recent cohorts don't get equal weight to large ones).
-- Limited to periods 1-12: a 12-month forward-looking horizon.
DROP TABLE IF EXISTS retail.overall_retention_curve;

CREATE TABLE retail.overall_retention_curve AS
SELECT
    period_number,
    SUM(active_customers)                                       AS active_customers,
    SUM(cohort_size)                                             AS total_customers,
    ROUND(100.0 * SUM(active_customers) / SUM(cohort_size), 1)   AS retention_pct
FROM retail.cohort_retention
WHERE period_number BETWEEN 1 AND 12
GROUP BY period_number
ORDER BY period_number;

-- Per-customer CLV: historical (already earned) + projected (next 12 months)
DROP TABLE IF EXISTS retail.customer_clv;

CREATE TABLE retail.customer_clv AS
WITH customer_tenure AS (
    SELECT
        cl.customer_id,
        cc.cohort_month,
        (
            (EXTRACT(YEAR  FROM MAX(DATE_TRUNC('month', cl.invoice_date))) - EXTRACT(YEAR  FROM cc.cohort_month)) * 12
          + (EXTRACT(MONTH FROM MAX(DATE_TRUNC('month', cl.invoice_date))) - EXTRACT(MONTH FROM cc.cohort_month))
          + 1
        )::INT AS tenure_months
    FROM retail.clean_lines cl
    JOIN retail.customer_cohort cc USING (customer_id)
    WHERE NOT cl.is_cancellation
    GROUP BY cl.customer_id, cc.cohort_month
),
horizon AS (
    -- sum of a survival curve = expected number of additional active months
    SELECT SUM(retention_pct) / 100.0 AS expected_active_months_12mo
    FROM retail.overall_retention_curve
)
SELECT
    r.customer_id,
    r.rfm_segment,
    r.frequency,
    r.monetary                                                                   AS historical_clv,
    ct.tenure_months,
    ROUND(r.monetary / r.frequency, 2)                                           AS aov,
    ROUND(r.frequency::NUMERIC / ct.tenure_months, 3)                            AS monthly_purchase_rate,
    h.expected_active_months_12mo,
    ROUND(
        (r.monetary / r.frequency) * (r.frequency::NUMERIC / ct.tenure_months) * h.expected_active_months_12mo,
        2
    )                                                                             AS projected_future_clv,
    ROUND(
        r.monetary + (r.monetary / r.frequency) * (r.frequency::NUMERIC / ct.tenure_months) * h.expected_active_months_12mo,
        2
    )                                                                             AS total_estimated_clv
FROM retail.customer_rfm r
JOIN customer_tenure ct USING (customer_id)
CROSS JOIN horizon h;

CREATE INDEX idx_clv_customer_id ON retail.customer_clv (customer_id);
CREATE INDEX idx_clv_segment     ON retail.customer_clv (rfm_segment);

COMMENT ON TABLE retail.customer_clv IS
  'Per-customer CLV: historical_clv is net revenue already earned (= RFM monetary). '
  'projected_future_clv = AOV x monthly purchase rate x expected active months over a '
  '12-month horizon, where expected active months comes from the dataset-wide retention '
  'curve (same curve applied to every segment — see 05_clv.sql header notes).';
