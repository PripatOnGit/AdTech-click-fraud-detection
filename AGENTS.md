# AI Agent Guidance for Ad-Tech Click Fraud Detection Project

## Project Overview

This is an **analytics and fraud detection project** that identifies fraudulent ad clicks, high-risk channels, and device-masking botnets using BigQuery SQL analysis on mobile ad traffic data.

**Key perspective:** Traffic-quality analyst protecting advertiser spend by blocklisting fraudulent IPs/channels.

See [README.md](README.md) for full project context, findings, and business recommendations.

---

## Core Pattern: Narrative Analytics Framework

The project follows a structured investigation narrative:

1. **Ask** — Define specific fraud detection questions
2. **Prepare** — Source and validate data
3. **Process** — Clean and transform (Google Sheets preprocessing documented)
4. **Analyze** — SQL-based detection (three independent methods)
5. **Share** — Tableau dashboard exports
6. **Act** — Business recommendations

When extending analysis, maintain this narrative structure and explicitly document which stage new work belongs to.

---

## SQL Conventions

### Structure
- **CTE-heavy**: Use CTEs for intermediate calculations (time windows, aggregations) — improves readability and debugging
- **Numbered files**: `01_*.sql`, `02_*.sql`, etc. reflect analysis sequence, not priority
- **Views**: All three main queries are also saved as BigQuery views (`v_burst_high_volume`, `v_channel_risk`, `v_device_masking`) for reuse

### Comments
- Include **business goal** at the top: `--Business Goal: ...`
- Explain **why** aggregations or filters matter (e.g., thresholds are percentile-based, not arbitrary)
- Document assumptions (e.g., CPC of $0.20/click in channel risk query)

### Key Techniques Used
- `LAG()` with `PARTITION BY ip ORDER BY click_time` for time-series gaps
- `TIMESTAMP_DIFF(... SECOND)` for burst detection
- `COUNT(DISTINCT ...)` for device masking (IP diversity anomalies)
- `SAFE_DIVIDE()` for safe null handling in CVR calculations
- Percentile-based thresholds calibrated to sample distribution (not hardcoded)

---

## Data Conventions

### Source & Schema
- **Input**: `adtech_fraud.click_logs` (BigQuery table)
  - Columns: `ip`, `app`, `device`, `os`, `channel`, `click_time`, `is_attributed`
  - See `docs/data_dictionary.md` for full field definitions
- **Processed CSV**: `data/processed/train_sample_clean.csv` (10,000 rows)
- **Quality**: Zero nulls; 0.31% baseline conversion rate (fraud-heavy traffic signature)

### Derived Metrics
- **CVR (Conversion Rate)**: `SUM(is_attributed) / COUNT(*) * 100`
- **Estimated spend**: Click count × $0.20 CPC (assumption for portfolio analysis)
- **Device diversity**: `COUNT(DISTINCT device)` per IP (anomaly if too high)

### Thresholds
⚠️ **Critical**: Current thresholds (percentile cutoffs for click volume, device count, CVR) were **recalibrated against this 10,000-row sample**. Do not reuse against different dataset sizes without re-running distribution analysis.

See `docs/build_log.md` for threshold calibration details and debugging notes.

---

## Common Development Patterns

### Data Quality Validation
- Always validate `is_attributed` is clean (0/1 only, no nulls)
- Spot-check click-count distribution via sample queries before and after transformation
- Use formula-based audits (Google Sheets) or SQL aggregations to verify row counts, nulls, date ranges

### Troubleshooting Patterns
- **String vs. TIMESTAMP silently breaks queries**: If `MAX(click_time)` returns unexpected results, check data type in BigQuery schema
- **CSV export stray columns**: Validate exported CSV structure matches expected schema before loading
- **Threshold zero results**: Before concluding fraud is absent, revalidate percentile distributions against actual sample—hardcoded thresholds may not fit new data

See `docs/build_log.md` for full debugging trails and lessons learned.

---

## Stakeholder Communication

### Executive Dashboard
- Lead with **headline metric**: estimated $ wasted spend (in this case, ~$317 on 634 fraudulent clicks)
- Back up with % of traffic flagged and confidence level (single vs. dual-method detection)

### Risk Categorization
Use consistent labels when flagging:
- **CRITICAL RISK**: 0% CVR at high volume (e.g., Channel 280: 787 clicks, 0 conversions)
- **HIGH RISK**: CVR far below baseline at meaningful volume
- **Dual-method flagged**: IPs detected by both burst *and* device-masking (highest confidence)

### Caveats to Always Include
- Dataset has no ground-truth fraud labels — detection uses proxy signals (CVR, volume, device diversity)
- Precision/recall not measurable without validation data
- Device diversity alone ≠ fraud (could be shared/NAT IP with multiple genuine users)

---

## Common Tasks

### Adding a New Detection Method
1. Create numbered SQL file: `04_*.sql`
2. Add business goal comment at top
3. Export results to CSV for dashboard integration
4. Save as BigQuery view for reuse
5. Update README.md "Analyze" table with technique, detection focus, and key findings
6. Document thresholds and caveats in `docs/build_log.md`

### Updating Thresholds
1. Re-run distribution analysis: percentiles of clicks/IP, device counts, CVR by channel
2. Document new thresholds and reasoning in `docs/build_log.md` with date
3. Re-test all three detection queries against sample
4. Update README findings if fraud detection results change materially

### Extending Dashboard
- Tableau Public only supports CSV exports (no live BigQuery connector)
- Export relevant views as CSV from BigQuery
- Update file paths in dashboard workbook
- Publish to Tableau Public and link in `dashboard/dashboard_link.md`

---

## Tools & Environment

- **BigQuery**: SQL analysis and view storage
- **Google Sheets**: Data preprocessing, validation formulas
- **Tableau Public**: Dashboard and portfolio sharing (snapshot-based, not live)
- **GitHub**: Version control and portfolio documentation
- **CSV**: Data interchange format between stages

---

## Limitations & Future Work

- **Ground truth**: Actual fraud labels not available—only proxy signals
- **Scale**: Findings validated on 10k-row sample; thresholds need re-validation for production traffic
- **CPC assumption**: $0.20/click is portfolio assumption, not platform data
- **Live refresh**: Tableau Public dashboard is a snapshot; full refresh requires manual CSV export from BigQuery

---

## Quick Reference: Key Files

| File | Purpose |
|------|---------|
| [README.md](README.md) | Full narrative: ask, prepare, process, analyze, share, act |
| [sql/01_rapid_burst_clicks.sql](sql/01_rapid_burst_clicks.sql) | Detect high-volume or rapid-succession clicking (LAG + TIMESTAMP_DIFF) |
| [sql/02_channel_risk_scoring.sql](sql/02_channel_risk_scoring.sql) | Channel-level fraud risk with CVR analysis |
| [sql/03_device_masking_anomalies.sql](sql/03_device_masking_anomalies.sql) | IP device diversity anomalies |
| [docs/data_dictionary.md](docs/data_dictionary.md) | Schema and field definitions |
| [docs/build_log.md](docs/build_log.md) | Debugging notes, threshold calibration, lessons learned |
| [data/processed/train_sample_clean.csv](data/processed/train_sample_clean.csv) | Cleaned 10k-row analysis dataset |
