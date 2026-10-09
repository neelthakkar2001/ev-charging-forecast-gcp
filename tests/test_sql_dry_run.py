import os
import pathlib

import pytest
from google.cloud import bigquery

FILES = ["05_verify_load", "06_eda", "15_check_features", "32_tree_input", "40_evaluate", "50_city_series"]


@pytest.mark.parametrize("name", FILES)
def test_sql_dry_runs(name):
    client = bigquery.Client(project=os.environ["GCP_PROJECT"], location="US")
    sql = (pathlib.Path("sql") / f"{name}.sql").read_text()
    job = client.query(sql, job_config=bigquery.QueryJobConfig(dry_run=True))
    assert job.total_bytes_processed >= 0
