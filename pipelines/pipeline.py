"""train (CustomJob) -> evaluate -> gate -> register only if the gate passes."""
import argparse

from google.cloud import aiplatform
from google_cloud_pipeline_components.v1.custom_job import CustomTrainingJobOp
from kfp import compiler, dsl

LOC = "us-central1"
SERVING = "us-docker.pkg.dev/vertex-ai/prediction/xgboost-cpu.2-1:latest"
BASE = "python:3.11-slim"


@dsl.component(base_image=BASE, packages_to_install=["google-cloud-bigquery", "google-cloud-storage"])
def evaluate(project: str, dataset: str, bucket: str, run_id: str) -> float:
    """Val WAPE from the BQ prediction table (source of truth), cross-checked with the container's number."""
    import json

    from google.cloud import bigquery, storage
    sql = f"""SELECT SAFE_DIVIDE(SUM(ABS(f.energy_kwh - p.y_hat)), SUM(f.energy_kwh)) AS w,
              COUNT(*) AS n, COUNTIF(p.y_hat IS NULL) AS nn
              FROM `{project}.{dataset}.pred_xgb_resid` p
              JOIN `{project}.{dataset}.features` f USING (ts, site_id) WHERE f.split = 'val'"""
    r = list(bigquery.Client(project=project).query(sql).result())[0]
    assert r.n == 1032672 and r.nn == 0, (r.n, r.nn)
    res = json.loads(storage.Client(project=project).bucket(bucket)
                     .blob(f"runs/{run_id}/result.json").download_as_text())
    assert abs(res["val_wape"] - r.w) < 1e-6, (res["val_wape"], r.w)
    return float(r.w)


@dsl.component(base_image=BASE, packages_to_install=["google-cloud-bigquery"])
def gate(project: str, dataset: str, run_id: str, candidate: float, threshold_override: float) -> str:
    """Pass only if the candidate beats naive_24h on val. threshold_override > 0 replaces the baseline (demo)."""
    from google.cloud import bigquery
    c = bigquery.Client(project=project)
    base = list(c.query(f"SELECT wape_site FROM `{project}.{dataset}.metrics` "
                        "WHERE model = 'naive_24h' AND split = 'val' AND bucket = 'all'").result())[0][0]
    forced = threshold_override > 0
    threshold = threshold_override if forced else base
    decision = "pass" if candidate < threshold else "block"
    c.query(f"""CREATE TABLE IF NOT EXISTS `{project}.{dataset}.gate_log`
                (logged_at TIMESTAMP, run_id STRING, candidate FLOAT64, baseline FLOAT64,
                 threshold FLOAT64, forced BOOL, decision STRING)""").result()
    c.query(f"INSERT `{project}.{dataset}.gate_log` VALUES (CURRENT_TIMESTAMP(), '{run_id}', "
            f"{candidate}, {base}, {threshold}, {forced}, '{decision}')").result()
    print(f"candidate {candidate:.4f} baseline {base:.4f} threshold {threshold:.4f} forced {forced} -> {decision}")
    return decision


@dsl.component(base_image=BASE, packages_to_install=["google-cloud-aiplatform"])
def register(project: str, bucket: str, run_id: str, forced: bool, serving_image: str):
    from google.cloud import aiplatform
    aiplatform.init(project=project, location="us-central1")
    aiplatform.Model.upload(
        display_name="ev_demand_xgb_resid" + ("_forced_demo" if forced else ""),
        artifact_uri=f"gs://{bucket}/runs/{run_id}/model",
        serving_container_image_uri=serving_image,
        labels={"gate": "forced" if forced else "passed"},
    )


def build(args):
    @dsl.pipeline(name="ev-xgb-gate")
    def pipeline(threshold_override: float = -1.0):
        train = CustomTrainingJobOp(
            project=args.project, location=LOC, display_name=f"xgb-resid-{args.run_id}-pipeline",
            timeout="5400s", service_account=args.sa,
            worker_pool_specs=[{
                "machine_spec": {"machine_type": "e2-standard-8"}, "replica_count": 1,
                "container_spec": {"image_uri": args.image,
                                   "args": ["--project", args.project, "--bucket", args.bucket,
                                            "--run-id", args.run_id]}}])
        ev = evaluate(project=args.project, dataset="ev_ds", bucket=args.bucket, run_id=args.run_id).after(train)
        g = gate(project=args.project, dataset="ev_ds", run_id=args.run_id,
                 candidate=ev.output, threshold_override=threshold_override)
        with dsl.If(g.output == "pass"):
            register(project=args.project, bucket=args.bucket, run_id=args.run_id,
                     forced=args.threshold_override > 0, serving_image=SERVING)
    return pipeline


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    for k in ("project", "bucket", "image", "sa", "run-id"):
        p.add_argument(f"--{k}", required=True)
    p.add_argument("--threshold-override", type=float, default=-1.0)
    a = p.parse_args()
    tpl = "pipelines/ev_xgb_gate.json"
    compiler.Compiler().compile(build(a), tpl)
    aiplatform.init(project=a.project, location=LOC)
    job = aiplatform.PipelineJob(display_name=f"ev-xgb-gate-{a.run_id}", template_path=tpl,
                                 pipeline_root=f"gs://{a.bucket}/pipeline_root",
                                 parameter_values={"threshold_override": a.threshold_override},
                                 enable_caching=True)
    job.submit(service_account=a.sa)
    print(job.resource_name)
    job.wait()
