-- ============================================================
-- Customer Analytics Suite — Stage 4: cohort retention
-- Run with:  psql -U postgres -d customer_analytics -f sql/04_cohort_retention.sql
-- ============================================================

-- Each customer's acquisition cohort = the calendar month of their first completed order
DROP TABLE IF EXISTS retail.customer_cohort;

CREATE TABLE retail.customer_cohort AS
SELECT
    customer_id,
    DATE_TRUNC('month', MIN(invoice_date))::date AS cohort_month
FROM retail.clean_lines
WHERE NOT is_cancellation
GROUP BY customer_id;

CREATE INDEX idx_cohort_customer_id ON retail.customer_cohort (customer_id);

-- Long-format retention table: for every cohort, how many of its original
-- customers were still active N calendar months later.
DROP TABLE IF EXISTS retail.cohort_retention;

CREATE TABLE retail.cohort_retention AS
WITH monthly_activity AS (
    SELECT DISTINCT
        customer_id,
        DATE_TRUNC('month', invoice_date)::date AS activity_month
    FROM retail.clean_lines
    WHERE NOT is_cancellation
),
cohort_activity AS (
    SELECT
        ma.customer_id,
        cc.cohort_month,
        (EXTRACT(YEAR FROM ma.activity_month) - EXTRACT(YEAR FROM cc.cohort_month)) * 12
            + (EXTRACT(MONTH FROM ma.activity_month) - EXTRACT(MONTH FROM cc.cohort_month))
            AS period_number
    FROM monthly_activity ma
    JOIN retail.customer_cohort cc USING (customer_id)
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS cohort_size
    FROM cohort_activity
    WHERE period_number = 0
    GROUP BY cohort_month
),
period_counts AS (
    SELECT cohort_month, period_number, COUNT(DISTINCT customer_id) AS active_customers
    FROM cohort_activity
    GROUP BY cohort_month, period_number
)
SELECT
    pc.cohort_month,
    pc.period_number::INT                                   AS period_number,
    pc.active_customers,
    cs.cohort_size,
    ROUND(100.0 * pc.active_customers / cs.cohort_size, 1)  AS retention_pct
FROM period_counts pc
JOIN cohort_sizes cs USING (cohort_month)
ORDER BY pc.cohort_month, pc.period_number;

COMMENT ON TABLE retail.cohort_retention IS
  'Long-format cohort retention: for each acquisition cohort (month of first '
  'completed order) and each period_number (calendar months since acquisition), '
  'the count and percentage of that cohort''s original customers who purchased again.';