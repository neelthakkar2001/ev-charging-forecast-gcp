SELECT
  creation_time,
  job_id,
  statement_type,
  total_bytes_billed,
  ROUND(total_bytes_billed / POW(1024, 4) * 312.5, 4) AS usd_at_create_model_rate
FROM `region-us`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 6 HOUR)
  AND statement_type = 'CREATE_MODEL'
ORDER BY creation_time DESC
LIMIT 5;
