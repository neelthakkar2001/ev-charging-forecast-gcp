SELECT
  (SELECT COUNT(*) FROM ev_ds.ev_raw) AS n_rows,
  (SELECT COUNT(DISTINCT site_id) FROM ev_ds.ev_raw) AS n_sites,
  (SELECT MIN(ts) FROM ev_ds.ev_raw) AS t_min,
  (SELECT MAX(ts) FROM ev_ds.ev_raw) AS t_max,
  (SELECT ROUND(SUM(energy_kwh)) FROM ev_ds.ev_raw) AS kwh_total,
  (SELECT COUNT(*) FROM ev_ds.weather_raw) AS weather_rows,
  (SELECT COUNT(DISTINCT v.ts) FROM ev_ds.ev_raw v JOIN ev_ds.weather_raw w USING (ts)) AS joined_hours;
