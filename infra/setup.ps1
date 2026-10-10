# Setup for the Vertex part of the project: APIs, Artifact Registry repo, service accounts, Workload
# Identity Federation for GitHub Actions, and the scoped roles. infra/teardown.ps1 undoes it.
# Run once from the repo root in PowerShell, logged in with `gcloud auth login`.
# Not included: the Cloud Storage bucket and BigQuery dataset ev_ds (created in the data load step).
# Edit $BUCKET and $GH_REPO for your own project and fork. The bucket must already exist.
$PROJECT = gcloud config get-value project
$REGION  = "us-central1"
$BUCKET  = "ev-forecast-2026-raw"
$GH_REPO = "neelthakkar2001/ev-charging-forecast-gcp"
$SA      = "ev-pipeline-sa@$PROJECT.iam.gserviceaccount.com"
$CI      = "ev-ci-sa@$PROJECT.iam.gserviceaccount.com"
$ME      = gcloud config get-value account

# 1. APIs, Artifact Registry repo, service accounts
gcloud services enable cloudbuild.googleapis.com artifactregistry.googleapis.com aiplatform.googleapis.com iam.googleapis.com iamcredentials.googleapis.com sts.googleapis.com storage.googleapis.com
gcloud artifacts repositories create ev --repository-format=docker --location=$REGION --description="EV forecast images"
gcloud iam service-accounts create ev-pipeline-sa --display-name="EV pipeline runner"
gcloud iam service-accounts create ev-ci-sa --display-name="EV CI dry-run"

# 2. Roles for the pipeline runner and the read-only CI account
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$SA" --role=roles/aiplatform.user
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$SA" --role=roles/bigquery.jobUser
# dataset-level `bq add-iam-policy-binding` needed allowlisting here, so the BigQuery data roles are project-level
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$SA" --role=roles/bigquery.dataEditor
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$SA" --role=roles/bigquery.readSessionUser
gcloud storage buckets add-iam-policy-binding gs://$BUCKET --member="serviceAccount:$SA" --role=roles/storage.objectAdmin
gcloud artifacts repositories add-iam-policy-binding ev --location=$REGION --member="serviceAccount:$SA" --role=roles/artifactregistry.reader
gcloud iam service-accounts add-iam-policy-binding $SA --member="user:$ME" --role=roles/iam.serviceAccountUser
gcloud iam service-accounts add-iam-policy-binding $SA --member="serviceAccount:$SA" --role=roles/iam.serviceAccountUser
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$CI" --role=roles/bigquery.jobUser
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$CI" --role=roles/bigquery.dataViewer

# 3. Workload Identity Federation for GitHub Actions: no keys, limited to this repository by its numeric id
$PN      = gcloud projects describe $PROJECT --format="value(projectNumber)"
$REPO_ID = gh api repos/$GH_REPO --jq .id
gcloud iam workload-identity-pools create gh-pool --location=global --display-name="GitHub"
gcloud iam workload-identity-pools providers create-oidc gh-provider --location=global --workload-identity-pool=gh-pool --issuer-uri="https://token.actions.githubusercontent.com/" --attribute-mapping="google.subject=assertion.sub,attribute.repository_id=assertion.repository_id" --attribute-condition="assertion.repository_id=='$REPO_ID'"
gcloud iam service-accounts add-iam-policy-binding $CI --role=roles/iam.workloadIdentityUser --member="principalSet://iam.googleapis.com/projects/$PN/locations/global/workloadIdentityPools/gh-pool/attribute.repository_id/$REPO_ID"
# then put the project id, project number and service account into .github/workflows/ci.yml
