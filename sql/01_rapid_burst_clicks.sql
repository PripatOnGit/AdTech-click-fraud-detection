--Query 1: Rapid-Fire Click Burst Detection (Botnets)
--Business Goal: Identify specific IP addresses triggering multiple ad clicks within seconds of each other—a primary indicator of automated script/bot activity.

-- File: sql/01_rapid_burst_clicks.sql
WITH time_differences AS (
  SELECT 
    ip,
    device,
    channel,
    click_time,
    -- Retrieve the timestamp of the previous click from the same IP
    LAG(click_time) OVER (PARTITION BY ip ORDER BY click_time) AS prev_click_time
  FROM `adtech_fraud.clicks_clean`
),
calculated_lags AS (
  SELECT 
    ip,
    device,
    channel,
    click_time,
    TIMESTAMP_DIFF(click_time, prev_click_time, SECOND) AS seconds_since_last_click
  FROM time_differences
  WHERE prev_click_time IS NOT NULL
)
SELECT 
  ip,
  COUNT(*) + 1 AS total_clicks_in_sample,
  ROUND(AVG(seconds_since_last_click) / 60, 2) AS avg_click_interval_minutes,
  ROUND(MIN(seconds_since_last_click) / 60, 2) AS min_click_interval_minutes
FROM calculated_lags
WHERE seconds_since_last_click <= 3600  -- Clicks occurring within 60 minutes
GROUP BY ip
HAVING total_clicks_in_sample >= 2
ORDER BY total_clicks_in_sample DESC;