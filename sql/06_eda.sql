WITH tr AS (
  -- train rows only: EDA must not look at val or test
  SELECT * FROM ev_ds.ev_raw WHERE ts < TIMESTAMP '2023-07-31 22:00:00+00'
),
site AS (
  SELECT site_id, SUM(energy_kwh) AS kwh FROM tr GROUP BY site_id
),
conc AS (
  SELECT
    SAFE_DIVIDE(SUM(IF(decile = 1, kwh, 0)), SUM(kwh)) AS top10pct_site_share,
    MIN(kwh) AS min_site_kwh,
    MAX(kwh) AS max_site_kwh
  FROM (SELECT kwh, NTILE(10) OVER (ORDER BY kwh DESC) AS decile FROM site)
),
city AS (
  SELECT ts, SUM(energy_kwh) AS y FROM tr GROUP BY ts
),
seas AS (
  SELECT CORR(y, l24) AS corr_lag_24h, CORR(y, l168) AS corr_lag_168h
  FROM (
    SELECT y, LAG(y, 24) OVER (ORDER BY ts) AS l24, LAG(y, 168) OVER (ORDER BY ts) AS l168
    FROM city
  )
),
quant AS (
  SELECT
    COUNTIF(t.energy_kwh = 0) / COUNT(*) AS share_zero,
    COUNTIF(t.energy_kwh = ROUND(t.energy_kwh)) / COUNT(*) AS share_whole_number,
    COUNTIF(t.energy_kwh > 0 AND t.energy_kwh = t.prev) / COUNT(*) AS share_repeat_prev_hour,
    MAX(SAFE_DIVIDE(t.energy_kwh, s.charger_num)) AS max_kwh_per_charger_hour,
    COUNTIF(t.energy_kwh IS NULL) AS n_null,
    COUNTIF(t.energy_kwh < 0) AS n_negative
  FROM (
    SELECT site_id, energy_kwh, LAG(energy_kwh) OVER (PARTITION BY site_id ORDER BY ts) AS prev
    FROM tr
  ) t
  JOIN ev_ds.sites_raw s USING (site_id)
)
SELECT * FROM conc, seas, quant;
