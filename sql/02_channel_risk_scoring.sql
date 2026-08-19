--Query 2: Publisher Channel Risk & Wasted Spend Analysis
--Business Goal: Categorize ad channels based on volume, conversion performance, and financial risk assuming a standard Cost-Per-Click (CPC) model of $0.20/click.

--file: sql/02_channel_risk_scoring.sql
WITH channel_summary AS (
  SELECT 
    channel,
    COUNT(*) AS total_clicks,
    SUM(is_attributed) AS total_conversions,
    -- Compute Conversion Rate (CVR %)
    ROUND(SAFE_DIVIDE(SUM(is_attributed), COUNT(*)) * 100, 2) AS conversion_rate_pct,
    -- Calculate estimated advertising spend at $0.20 per click
    COUNT(*) * 0.20 AS estimated_ad_spend
  FROM `adtech_fraud.clicks_clean`
  GROUP BY channel
)
SELECT 
  channel,
  total_clicks,
  total_conversions,
  conversion_rate_pct,
  estimated_ad_spend,
  -- Assign automated risk status
  CASE 
    WHEN total_clicks >= 100 AND conversion_rate_pct = 0.0 THEN 'CRITICAL RISK (Pure Click Spam)'
    WHEN total_clicks >= 50 AND conversion_rate_pct < 0.2 THEN 'HIGH RISK (Low Conversion)'
    WHEN conversion_rate_pct >= 1.0 THEN 'HIGH PERFORMING / CLEAN'
    ELSE 'MODERATE / NEUTRAL'
  END AS channel_risk_status
FROM channel_summary
WHERE total_clicks >= 20
ORDER BY estimated_ad_spend DESC;