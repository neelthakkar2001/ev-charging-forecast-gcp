CREATE OR REPLACE TABLE ev_ds.city_hourly AS
SELECT
  v.ts,
  SUM(v.energy_kwh) AS y,
  MAX(w.temp) AS temp, MAX(w.precip) AS precip, MAX(w.solarradiation) AS solarradiation,
  MAX(w.windspeed) AS windspeed, MAX(w.cloudcover) AS cloudcover, MAX(w.humidity) AS humidity
FROM ev_ds.ev_raw v
JOIN ev_ds.weather_raw w USING (ts)
GROUP BY v.ts;
