WITH f AS (SELECT * FROM ev_ds.features),
lagchk AS (
  SELECT
    COUNTIF(a.lag_24h  IS DISTINCT FROM p24.energy_kwh)  AS bad_lag_24h,
    COUNTIF(a.lag_168h IS DISTINCT FROM p168.energy_kwh) AS bad_lag_168h,
    COUNTIF(a.lag_672h IS DISTINCT FROM p672.energy_kwh) AS bad_lag_672h
  FROM f a
  LEFT JOIN f p24  ON p24.site_id  = a.site_id AND p24.ts  = TIMESTAMP_SUB(a.ts, INTERVAL 24 HOUR)
  LEFT JOIN f p168 ON p168.site_id = a.site_id AND p168.ts = TIMESTAMP_SUB(a.ts, INTERVAL 168 HOUR)
  LEFT JOIN f p672 ON p672.site_id = a.site_id AND p672.ts = TIMESTAMP_SUB(a.ts, INTERVAL 672 HOUR)
),
s1 AS (SELECT MIN(site_id) AS site_id FROM f),
one AS (SELECT f.ts, f.energy_kwh, f.mean_7d FROM f JOIN s1 USING (site_id)),
roll AS (
  SELECT a.ts, AVG(h.energy_kwh) AS m
  FROM one a
  JOIN one h ON h.ts BETWEEN TIMESTAMP_SUB(a.ts, INTERVAL 191 HOUR) AND TIMESTAMP_SUB(a.ts, INTERVAL 24 HOUR)
  GROUP BY a.ts
  HAVING COUNT(*) = 168
),
rollchk AS (
  SELECT COUNTIF((o.mean_7d IS NULL) != (r.m IS NULL) OR ABS(o.mean_7d - r.m) > 1e-6) AS bad_mean_7d
  FROM one o LEFT JOIN roll r USING (ts)
)
SELECT
  l.bad_lag_24h, l.bad_lag_168h, l.bad_lag_672h, r.bad_mean_7d,
  (SELECT COUNT(*) FROM f) AS n_rows,
  (SELECT COUNT(*) FROM (SELECT 1 FROM f GROUP BY ts, site_id HAVING COUNT(*) > 1)) AS dup_keys,
  (SELECT COUNTIF(temp IS NULL OR precip IS NULL OR solarradiation IS NULL OR windspeed IS NULL OR cloudcover IS NULL OR humidity IS NULL) FROM f) AS weather_nulls,
  (SELECT COUNTIF(charger_num IS NULL OR latitude IS NULL OR longitude IS NULL OR perimeter IS NULL OR area IS NULL) FROM f) AS site_nulls,
  (SELECT COUNT(DISTINCT DATE(ts, 'Europe/Amsterdam')) FROM f WHERE is_holiday_nl) AS holiday_days,
  (SELECT MIN(c) FROM (SELECT COUNT(*) AS c FROM f GROUP BY site_id)) AS min_hours_per_site,
  (SELECT MAX(c) FROM (SELECT COUNT(*) AS c FROM f GROUP BY site_id)) AS max_hours_per_site,
  (SELECT COUNTIF(split = 'train') FROM f) AS n_train,
  (SELECT COUNTIF(split = 'val') FROM f) AS n_val,
  (SELECT COUNTIF(split = 'test') FROM f) AS n_test,
  (SELECT MAX(ts) FROM f WHERE split = 'train') AS train_max,
  (SELECT MIN(ts) FROM f WHERE split = 'val') AS val_min,
  (SELECT MAX(ts) FROM f WHERE split = 'val') AS val_max,
  (SELECT MIN(ts) FROM f WHERE split = 'test') AS test_min,
  (SELECT MAX(ts) FROM f WHERE split = 'test') AS test_max
FROM lagchk l, rollchk r;
