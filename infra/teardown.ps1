# Teardown for the EV forecast project. Mirrors infra/setup.ps1 in reverse.
# Default is a DRY RUN: it only lists what exists and what it would delete.
#   .\infra\teardown.ps1                  list everything, delete nothing
#   .\infra\teardown.ps1 -Execute         delete the billable and identity resources
#   .\infra\teardown.ps1 -Execute -DeleteRawData   also delete raw/ and processed/ in the bucket
# Kept on purpose: the BigQuery dataset ev_ds (inside the free tier) and, unless -DeleteRawData, the raw data.
param([switch]$Execute, [switch]$DeleteRawData)

$PROJECT = gcloud config get-value project
$REGION  = "us-central1"
$BUCKET  = "ev-forecast-2026-raw"
$SA      = "ev-pipeline-sa@$PROJECT.iam.gserviceaccount.com"
$CI      = "ev-ci-sa@$PROJECT.iam.gserviceaccount.com"
"project: $PROJECT   bucket: $BUCKET   mode: $(if ($Execute) { 'EXECUTE' } else { 'DRY RUN' })"

function Act([string]$what, [scriptblock]$do) {
    if ($Execute) { "DELETE: $what"; & $do } else { "would delete: $what" }
}

"`n== 1. endpoints (must be empty; they bill per node-hour) =="
$eps = gcloud ai endpoints list --region=$REGION --format="value(name)"
if ($eps) {
    "Endpoints exist, undeploy and delete them by hand first:"; $eps
    exit 1
}
"none"

"`n== 2. Vertex Model Registry models =="
$models = gcloud ai models list --region=$REGION --format="value(name)"
# BigQuery ML models registered in Vertex cannot be deleted from Vertex (the call errors). They cost nothing
# and are left; delete the BigQuery model itself (bq rm -m) if you want them gone.
foreach ($m in $models) {
    Act "model $m" { gcloud ai models delete $m --region=$REGION --quiet }
}
if (-not $models) { "none" }

"`n== 3. Artifact Registry repository ev (the training image) =="
gcloud artifacts repositories list --location=$REGION --format="value(name)"
Act "repository ev" { gcloud artifacts repositories delete ev --location=$REGION --quiet }

"`n== 4. bucket contents =="
gcloud storage ls "gs://$BUCKET/"
Act "gs://$BUCKET/runs and gs://$BUCKET/pipeline_root" {
    gcloud storage rm -r "gs://$BUCKET/runs" "gs://$BUCKET/pipeline_root"
}
if ($DeleteRawData) {
    Act "gs://$BUCKET/raw and gs://$BUCKET/processed" {
        gcloud storage rm -r "gs://$BUCKET/raw" "gs://$BUCKET/processed"
    }
} else { "raw/ and processed/ kept (use -DeleteRawData to remove them)" }

"`n== 4b. buckets created by Cloud Build and Vertex (source uploads, staging) =="
$svcBuckets = gcloud storage buckets list --format="value(name)" | Where-Object { $_ -eq "${PROJECT}_cloudbuild" -or $_ -like "cloud-ai-platform-*" }
foreach ($b in $svcBuckets) { Act "bucket gs://$b" { gcloud storage rm -r "gs://$b" } }
if (-not $svcBuckets) { "none" }

"`n== 5. Vertex Experiments: ev-demand =="
Act "experiment ev-demand" {
    python -c "from google.cloud import aiplatform as a; a.init(project='$PROJECT', location='$REGION'); a.Experiment('ev-demand').delete()"
}

"`n== 6. Workload Identity Federation (provider first, then pool) =="
gcloud iam workload-identity-pools list --location=global --format="value(name)"
Act "provider gh-provider" {
    gcloud iam workload-identity-pools providers delete gh-provider --location=global --workload-identity-pool=gh-pool --quiet
}
Act "pool gh-pool" { gcloud iam workload-identity-pools delete gh-pool --location=global --quiet }

"`n== 7. project-level roles of the service accounts, then the accounts =="
$bindings = @(
    @($SA, "roles/aiplatform.user"), @($SA, "roles/bigquery.jobUser"), @($SA, "roles/bigquery.dataEditor"),
    @($SA, "roles/bigquery.readSessionUser"), @($CI, "roles/bigquery.jobUser"), @($CI, "roles/bigquery.dataViewer")
)
foreach ($b in $bindings) {
    Act "role $($b[1]) for $($b[0])" {
        gcloud projects remove-iam-policy-binding $PROJECT --member="serviceAccount:$($b[0])" --role=$($b[1]) --quiet
    }
}
gcloud iam service-accounts list --format="value(email)"
Act "service account $SA" { gcloud iam service-accounts delete $SA --quiet }
Act "service account $CI" { gcloud iam service-accounts delete $CI --quiet }

"`n== check: what is left =="
"endpoints:";  gcloud ai endpoints list --region=$REGION
"models:";     gcloud ai models list --region=$REGION
"repos:";      gcloud artifacts repositories list --location=$REGION
"accounts:";   gcloud iam service-accounts list
"WIF pools:";  gcloud iam workload-identity-pools list --location=global
"bucket:";     gcloud storage ls "gs://$BUCKET/"
"running jobs:"; gcloud ai custom-jobs list --region=$REGION --filter="state=JOB_STATE_RUNNING"
"BigQuery dataset ev_ds is kept."
