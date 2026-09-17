# Ad-Tech Click Fraud & Traffic Anomaly Detection

Tableau Dashboard: https://public.tableau.com/app/profile/priyanka.patil2211/viz/Ad-TechFraudDetectionAnalysis/AD-TechFraudDetectionAnalysisDashboard

An end-to-end analytics project identifying fraudulent ad clicks, high-risk channels, and botnet-style device masking in mobile ad traffic, built on a sample of the Kaggle TalkingData AdTracking dataset.

**Stack:** Google Sheets (preprocessing) → BigQuery (SQL analytics) → CSV export → Tableau Public (dashboard) → GitHub (portfolio)


**Perspective:** analyst on a mobile ad network's traffic-quality team — protecting advertiser spend by identifying and blocklisting fraudulent publishers/IPs before advertisers notice wasted budget.

---

## 1. Ask

Digital ad platforms lose budget to click farms and botnets that inflate CPC spend without generating real app installs or conversions. This project answers three questions:

1. Which IPs are generating bot-like rapid-succession or abnormally high-volume clicks?
2. Which ad channels have conversion rates far below baseline at meaningful click volume?
3. Which IPs are rotating across an abnormal number of devices/OS combinations (a device-masking signature)?

**Headline metric:** estimated $ wasted ad spend (leads the executive story), backed by % of traffic flagged as fraud (operational tracking metric).

## 2. Prepare

- **Source:** Kaggle TalkingData AdTracking Fraud Detection Challenge — a 10,000-row sample of `train_sample.csv` (the official Kaggle file is 100k rows and additionally includes `attributed_time`, which this analysis does not use)
- **Schema:** `ip`, `app`, `device`, `os`, `channel`, `click_time`, `is_attributed` — see `docs/data_dictionary.md` for full field definitions
- **Data quality:** zero nulls across all columns; `is_attributed` conversion rate = 0.31% (31/10,000), consistent with fraud-heavy ad traffic
- **Scale:** 7,423 unique IPs, 135 channels, spanning Nov 6–9, 2017

## 3. Process

Cleaning and transformation done in Google Sheets before loading to BigQuery:
- Parsed `click_time` into a true datetime type, and derived `click_date`, `click_hour`, `click_dow` helper columns
- Validated data quality with formula-based audits: zero nulls, `is_attributed` confirmed clean 0/1, baseline CVR confirmed at 0.31%
- Spot-checked click-count distribution by IP via pivot table
- Exported to `data/processed/train_sample_clean.csv` (10,000 rows × 11 columns) and loaded into BigQuery

**Caught in process:** the first CSV export accidentally included two stray columns from nearby scratch-formula cells — stripped before use. On the BigQuery load side, `click_time` initially loaded as STRING instead of TIMESTAMP, which silently broke `MAX(click_time)` (string sort put `9:59:46` after `15:59:44`, since it compares text, not time). Caught via a planned validation query, fixed with `PARSE_TIMESTAMP` — see `docs/build_log.md` for the full debugging trail.

## 4. Analyze

Three BigQuery SQL scripts in `/sql`, built with CTEs, window functions, and conditional aggregation. All three are also saved as BigQuery views for stable, reusable querying (`v_burst_high_volume`, `v_channel_risk`, `v_device_masking`).

| Script | Technique | Detects |
|---|---|---|
| `01_rapid_burst_clicks.sql` | `LAG` + `TIMESTAMP_DIFF`, percentile-based thresholding | IPs with high total click volume (>p99) and/or rapid-succession clicking (≤5 min gaps) |
| `02_channel_risk_scoring.sql` | Aggregation + `CASE` | Channels with CVR far below baseline at meaningful volume |
| `03_device_masking_anomalies.sql` | `COUNT(DISTINCT ...)` | IPs cycling through an abnormal number of distinct devices |

**Threshold note:** initial thresholds were calibrated for the official 100k-row dataset and returned zero results against this 10,000-row sample. Recalibrated against this sample's actual statistical distribution (percentiles of clicks/IP, device-count distribution) rather than reusing arbitrary fixed cutoffs — full reasoning in `docs/build_log.md`.

### Key findings

- **Channel 280** flagged High Risk: 787 clicks, **0 conversions**, 0.00% CVR — 7.9% of all traffic from a channel converting nothing. 11 additional channels flagged Medium Risk (3,549 clicks).
- **39 unique IPs** flagged across the two IP-level detection methods, 634 total clicks (~6.3% of traffic).
- **4 IPs flagged by both methods** — the highest-confidence blocklist candidates: `5348, 5314, 17149, 105560`.
- **IP 5348**, the single strongest case: 76 clicks, 0 conversions, spread across 4 devices, 33 OS versions, 21 apps, and 39 channels in 3 days.
- **Caveat:** IP `17149` (3 devices, 18 clicks) has a 5.56% CVR — above baseline. Device diversity alone isn't proof of fraud; it can reflect a shared/NAT IP with multiple genuine users. Flagged for review, not automatic blocklisting.

## 5. Share

Interactive Tableau Public "Fraud Command Dashboard" (see `dashboard/dashboard_screenshot.png`):
- KPI header: Total Clicks (10,000), Overall CVR (0.31%), High-Risk Channel Clicks (787), Flagged Fraud IPs (39)
- Hourly Click Volume line chart — full 24-hour pattern, including a notable quiet period between hours 16–21 UTC
- Channel Risk bar chart, sorted by volume, colored by risk category
- Device Masking table, filtered to flagged IPs only
- Burst High Volume table, grouped by risk tier

**Architecture note:** Tableau Public doesn't support a live BigQuery connector (only Tableau Desktop/Server/Cloud do). The dashboard is built from 4 CSV exports of the BigQuery views/table rather than a live connection — a snapshot of the analysis rather than an auto-refreshing feed. Standard practice for Tableau Public portfolio pieces.

*(Tableau Public link: add once published — see `dashboard/dashboard_link.md`)*

## 6. Act

Recommended actions for the ad network's traffic-quality and marketing teams:

1. **Blocklist channel 280** immediately — 787 clicks and 0 conversions is not statistical noise at this volume; reallocate that budget toward channels with proven CVR above baseline. Review the 11 Medium Risk channels on a shorter timeline.
2. **Prioritize IPs `5348, 5314, 17149, 105560`** for blocklisting — flagged by both independent detection methods (volume/velocity AND device masking), the highest-confidence fraud signal in this analysis. Manually review `17149` given its above-baseline CVR before blocklisting.
3. **Estimated impact:** using a disclosed assumed CPC of $0.50 (mobile ad benchmark — actual CPC isn't in this dataset), the 634 clicks from flagged IPs represent roughly **$317 in estimated wasted spend** on this 10,000-click sample. This would scale with real production traffic volume.
4. **Re-baseline thresholds regularly** — the percentile-based cutoffs used here are fitted to this specific sample's distribution. Re-run the distribution check before reusing them against a different or larger dataset.

### Limitations

- This dataset has no ground-truth fraud labels — detection is based on proxy signals (low CVR, high volume, device diversity), not validated fraud outcomes. Precision/recall of this approach is not measurable with this data alone.
- The $0.50 CPC used for cost estimates is an assumption, disclosed above, not real platform pricing data.
- This is a 10,000-row sample; thresholds and findings would need re-validation against full-scale production traffic.

---

## Repository structure

```
adtech-click-fraud-bigquery/
├── data/
│   ├── raw/            # original Kaggle CSV
│   └── processed/      # cleaned CSV loaded into BigQuery
├── sql/
│   ├── 01_rapid_burst_clicks.sql
│   ├── 02_channel_risk_scoring.sql
│   └── 03_device_masking_anomalies.sql
├── dashboard/           # Tableau workbook, screenshot, published link
├── docs/
│   ├── data_dictionary.md
│   └── build_log.md    # full decision & debugging trail
└── README.md
```
