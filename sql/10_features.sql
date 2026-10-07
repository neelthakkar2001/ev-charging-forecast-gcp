CREATE OR REPLACE TABLE ev_ds.features AS
WITH lagged AS (
  SELECT
    ts, site_id, energy_kwh,
    LAG(energy_kwh, 24)  OVER w AS lag_24h,
    LAG(energy_kwh, 48)  OVER w AS lag_48h,
    LAG(energy_kwh, 168) OVER w AS lag_168h,
    LAG(energy_kwh, 336) OVER w AS lag_336h,
    LAG(energy_kwh, 504) OVER w AS lag_504h,
    LAG(energy_kwh, 672) OVER w AS lag_672h,
    IF(COUNT(energy_kwh) OVER w7 = 168, AVG(energy_kwh) OVER w7, NULL) AS mean_7d
  FROM ev_ds.ev_raw
  WINDOW w AS (PARTITION BY site_id ORDER BY ts),
         w7 AS (PARTITION BY site_id ORDER BY ts ROWS BETWEEN 191 PRECEDING AND 24 PRECEDING)
)
SELECT
  l.ts, l.site_id, l.energy_kwh,
  CASE WHEN l.ts < TIMESTAMP '2023-07-31 22:00:00+00' THEN 'train'
       WHEN l.ts < TIMESTAMP '2023-08-31 22:00:00+00' THEN 'val'
       ELSE 'test' END AS split,
  l.lag_24h, l.lag_48h, l.lag_168h, l.lag_336h, l.lag_504h, l.lag_672h,
  l.mean_7d,
  (l.lag_168h + l.lag_336h + l.lag_504h + l.lag_672h) / 4 AS mean_4w_same_hour,
  EXTRACT(HOUR FROM l.ts AT TIME ZONE 'Europe/Amsterdam') AS hr,
  EXTRACT(DAYOFWEEK FROM l.ts AT TIME ZONE 'Europe/Amsterdam') AS dow,
  EXTRACT(DAYOFWEEK FROM l.ts AT TIME ZONE 'Europe/Amsterdam') IN (1, 7) AS is_weekend,
  DATE(l.ts, 'Europe/Amsterdam') IN UNNEST([DATE '2023-04-09', DATE '2023-04-10', DATE '2023-04-27',
                                            DATE '2023-05-18', DATE '2023-05-28', DATE '2023-05-29']) AS is_holiday_nl,
  w.temp, w.precip, w.solarradiation, w.windspeed, w.cloudcover, w.humidity,
  s.charger_num, s.latitude, s.longitude, s.perimeter, s.area
FROM lagged l
LEFT JOIN ev_ds.weather_raw w USING (ts)
LEFT JOIN ev_ds.sites_raw s USING (site_id);
