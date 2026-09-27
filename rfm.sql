-- ============================================================
-- Customer Analytics Suite — Stage 3: RFM segmentation
-- Run with:  psql -U postgres -d customer_analytics -f sql/03_rfm.sql
-- ============================================================

DROP TABLE IF EXISTS retail.customer_rfm;

CREATE TABLE retail.customer_rfm AS
WITH snapshot AS (
    -- Historical data — "today" is the day after the last invoice in the
    -- dataset, not the real current date.
    SELECT MAX(invoice_date)::date + INTERVAL '1 day' AS snapshot_date
    FROM retail.clean_lines
),
customer_metrics AS (
    SELECT
        cl.customer_id,
        -- Recency: days since last COMPLETED purchase (cancellations don't count)
        (s.snapshot_date::date
            - (MAX(cl.invoice_date) FILTER (WHERE NOT cl.is_cancellation))::date
        )::INT                                                              AS recency_days,
        -- Frequency: distinct completed orders
        COUNT(DISTINCT cl.invoice) FILTER (WHERE NOT cl.is_cancellation)    AS frequency,
        -- Monetary: net revenue (purchases minus returns)
        SUM(cl.line_revenue)                                                AS monetary
    FROM retail.clean_lines cl
    CROSS JOIN snapshot s
    GROUP BY cl.customer_id, s.snapshot_date
    -- drop customers whose only activity was a cancellation with no completed order
    HAVING COUNT(DISTINCT cl.invoice) FILTER (WHERE NOT cl.is_cancellation) > 0
),
scored AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,  -- most recent   -> 5
        NTILE(5) OVER (ORDER BY frequency ASC)     AS f_score,  -- most frequent -> 5
        NTILE(5) OVER (ORDER BY monetary ASC)      AS m_score   -- highest spend -> 5
    FROM customer_metrics
),
scored_fm AS (
    SELECT *, ROUND((f_score + m_score) / 2.0) AS fm_score
    FROM scored
)
SELECT
    customer_id,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    fm_score,
    CASE
        WHEN r_score >= 4 AND fm_score >= 4 THEN 'Champions'
        WHEN r_score >= 4 AND fm_score >= 2 THEN 'Potential Loyalists'
        WHEN r_score >= 4                   THEN 'New Customers'
        WHEN r_score  = 3 AND fm_score >= 4 THEN 'Loyal Customers'
        WHEN r_score  = 3 AND fm_score >= 2 THEN 'Needs Attention'
        WHEN r_score  = 3                   THEN 'About to Sleep'
        WHEN r_score <= 2 AND fm_score >= 4 THEN 'At Risk'
        WHEN r_score <= 2 AND fm_score >= 2 THEN 'Hibernating'
        ELSE 'Lost'
    END AS rfm_segment
FROM scored_fm;

CREATE INDEX idx_rfm_customer_id ON retail.customer_rfm (customer_id);
CREATE INDEX idx_rfm_segment     ON retail.customer_rfm (rfm_segment);

COMMENT ON TABLE retail.customer_rfm IS
  'One row per customer: Recency (days since last completed order), Frequency '
  '(completed order count), Monetary (net revenue), their 1-5 quintile scores, '
  'and a named segment derived from the Recency score and the combined F+M score.';