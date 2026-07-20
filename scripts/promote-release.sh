#!/usr/bin/env bash
set -euo pipefail

app="${1:?app name is required}"
release="${2:?release name is required}"
project="${GCP_DEPLOY_PROJECT:?GCP_DEPLOY_PROJECT is required}"
region="${GCP_DEPLOY_REGION:-asia-northeast1}"

exec gcloud deploy releases promote \
  --delivery-pipeline="$app" \
  --release="$release" \
  --to-target="${app}-prod" \
  --project="$project" \
  --region="$region" \
  --quiet

