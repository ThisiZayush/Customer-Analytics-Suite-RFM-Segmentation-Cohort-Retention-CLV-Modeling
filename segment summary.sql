
DROP TABLE IF EXISTS retail.segment_summary;

CREATE TABLE retail.segment_summary AS
SELECT
    c.rfm_segment,
    COUNT(*)                                                                     AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)                           AS pct_of_customers,
    ROUND(AVG(r.recency_days), 0)                                                AS avg_recency_days,
    ROUND(AVG(c.frequency), 1)                                                   AS avg_frequency,
    ROUND(100.0 * COUNT(*) FILTER (WHERE c.frequency > 1) / COUNT(*), 1)         AS pct_repeat_customers,
    ROUND(AVG(c.historical_clv), 2)                                              AS avg_historical_clv,
    ROUND(SUM(c.historical_clv), 2)                                              AS segment_historical_revenue,
    ROUND(100.0 * SUM(c.historical_clv) / SUM(SUM(c.historical_clv)) OVER (), 1) AS pct_of_historical_revenue,
    ROUND(AVG(c.projected_future_clv), 2)                                        AS avg_projected_future_clv,
    ROUND(AVG(c.total_estimated_clv), 2)                                         AS avg_total_estimated_clv,
    ROUND(SUM(c.total_estimated_clv), 2)                                         AS segment_total_estimated_clv
FROM retail.customer_clv c
JOIN retail.customer_rfm r USING (customer_id)
GROUP BY c.rfm_segment
ORDER BY avg_total_estimated_clv DESC;

COMMENT ON TABLE retail.segment_summary IS
  'One row per RFM segment: size, revenue share, recency, repeat-purchase rate, '
  'and historical/projected/total CLV. The single source of truth for the final '
  'targeting recommendation.';
