import sys

from google.cloud import aiplatform

project, bucket, image, sa, run_id = sys.argv[1:6]
aiplatform.init(project=project, location="us-central1", staging_bucket=f"gs://{bucket}")
job = aiplatform.CustomJob(
    display_name=f"xgb-resid-{run_id}",
    worker_pool_specs=[{
        "machine_spec": {"machine_type": "e2-standard-8"},
        "replica_count": 1,
        "container_spec": {"image_uri": image,
                           "args": ["--project", project, "--bucket", bucket, "--run-id", run_id]},
    }],
)
job.run(service_account=sa, timeout=5400)  # 90 min stop-loss
