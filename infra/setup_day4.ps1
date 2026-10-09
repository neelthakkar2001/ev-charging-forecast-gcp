# Day 4 IAM setup. Run once from the repo root. Day 5 teardown reads this file.
$PROJECT = gcloud config get-value project
$REGION  = "us-central1"
$BUCKET  = "ev-forecast-2026-raw"
$SA      = "ev-pipeline-sa@$PROJECT.iam.gserviceaccount.com"
$CI      = "ev-ci-sa@$PROJECT.iam.gserviceaccount.com"
$ME      = gcloud config get-value account

gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$SA" --role=roles/aiplatform.user
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$SA" --role=roles/bigquery.jobUser
# dataset-level `bq add-iam-policy-binding` needs allowlisting here, so the roles below are project-level
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$SA" --role=roles/bigquery.dataEditor
gcloud storage buckets add-iam-policy-binding gs://$BUCKET --member="serviceAccount:$SA" --role=roles/storage.objectAdmin
gcloud artifacts repositories add-iam-policy-binding ev --location=$REGION --member="serviceAccount:$SA" --role=roles/artifactregistry.reader
gcloud iam service-accounts add-iam-policy-binding $SA --member="user:$ME" --role=roles/iam.serviceAccountUser
gcloud iam service-accounts add-iam-policy-binding $SA --member="serviceAccount:$SA" --role=roles/iam.serviceAccountUser
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$CI" --role=roles/bigquery.jobUser
bq add-iam-policy-binding --member="serviceAccount:$CI" --role=roles/bigquery.dataViewer "${PROJECT}:ev_ds"
