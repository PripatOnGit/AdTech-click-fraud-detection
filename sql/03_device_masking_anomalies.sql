--Query 3: Multi-Device Masking Detection (IP Anomaly Scoring)
--Business Goal: Detect single IP addresses rotating multiple device types and operating system versions—a technique used by proxy farms to hide their identity.

-- File: sql/03_device_masking_anomalies.sql
SELECT 
  ip,
  COUNT(DISTINCT device) AS unique_devices_used,
  COUNT(DISTINCT os) AS unique_os_versions_used,
  COUNT(*) AS total_ip_clicks,
  SUM(is_attributed) AS total_installs
FROM `adtech_fraud.click_logs`
GROUP BY ip
HAVING unique_devices_used > 2 AND unique_os_versions_used > 2
ORDER BY total_ip_clicks DESC;