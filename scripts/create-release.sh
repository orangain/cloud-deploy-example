#!/usr/bin/env bash
set -euo pipefail

app="${1:?app name is required}"
release="${2:?release name is required}"
project="${GCP_DEPLOY_PROJECT:?GCP_DEPLOY_PROJECT is required}"
region="${GCP_DEPLOY_REGION:-asia-northeast1}"
image="${APP_IMAGE:-us-docker.pkg.dev/cloudrun/container/hello:latest}"

exec gcloud deploy releases create "$release" \
  --delivery-pipeline="$app" \
  --project="$project" \
  --region="$region" \
  --source="apps/$app" \
  --images="APP_IMAGE=$image" \
  --annotations="commitSha=${GITHUB_SHA:-local},app=$app"

