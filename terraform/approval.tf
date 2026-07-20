resource "google_pubsub_topic" "production_approval_requests" {
  project = var.deploy_project_id
  name    = "cloud-deploy-production-approval-requests"

  depends_on = [google_project_service.deploy]
}

resource "google_pubsub_topic_iam_member" "github_publishes_approval_requests" {
  project = var.deploy_project_id
  topic   = google_pubsub_topic.production_approval_requests.name
  role    = "roles/pubsub.publisher"
  member  = google_service_account.github_deployer.member
}

resource "google_cloudbuild_trigger" "production_batch_approval" {
  project     = var.deploy_project_id
  location    = var.region
  name        = "approve-production-batch"
  description = "Approve all production rollouts in a release batch"

  service_account = google_service_account.batch_approver.id

  pubsub_config {
    topic = google_pubsub_topic.production_approval_requests.id
  }

  approval_config {
    approval_required = true
  }

  substitutions = {
    _RELEASE        = "$(body.message.attributes.release)"
    _APPS           = "$(body.message.attributes.apps)"
    _DEPLOY_PROJECT = var.deploy_project_id
    _DEPLOY_REGION  = var.region
  }

  build {
    step {
      name       = "gcr.io/google.com/cloudsdktool/google-cloud-cli:slim"
      entrypoint = "bash"
      args = [
        "-ceu",
        <<-EOT
          release="$1"
          apps_csv="$2"
          project="$3"
          region="$4"

          [[ "$$release" =~ ^git-[0-9a-f]{12}-[1-9][0-9]*$ ]] || {
            echo "Invalid release ID: $$release" >&2
            exit 1
          }
          [[ -n "$$apps_csv" ]] || {
            echo "No applications were requested" >&2
            exit 1
          }

          app_count="$$(tr ',' '\n' <<< "$$apps_csv" | wc -l)"
          echo "Approving release $$release for $$app_count application(s): $$apps_csv"

          while IFS= read -r app; do
            [[ "$$app" =~ ^[a-z][a-z0-9-]{0,48}$ ]] || {
              echo "Invalid application ID: $$app" >&2
              exit 1
            }

            rollout="$$(gcloud deploy rollouts list \
              --delivery-pipeline="$$app" \
              --release="$$release" \
              --project="$$project" \
              --region="$$region" \
              --filter="targetId=$$app-prod AND state=PENDING_APPROVAL" \
              --format='value(name.basename())')"

            [[ -n "$$rollout" ]] || {
              echo "No pending production rollout found for $$app / $$release" >&2
              exit 1
            }
            [[ "$$(wc -w <<< "$$rollout")" -eq 1 ]] || {
              echo "Multiple pending rollouts found for $$app / $$release" >&2
              exit 1
            }

            gcloud deploy rollouts approve "$$rollout" \
              --delivery-pipeline="$$app" \
              --release="$$release" \
              --project="$$project" \
              --region="$$region" \
              --quiet
          done < <(tr ',' '\n' <<< "$$apps_csv")
        EOT
        ,
        "--",
        "$${_RELEASE}",
        "$${_APPS}",
        "$${_DEPLOY_PROJECT}",
        "$${_DEPLOY_REGION}",
      ]
    }

    timeout = "1200s"

    options {
      logging = "CLOUD_LOGGING_ONLY"
    }
  }

  depends_on = [
    google_project_iam_member.batch_approver_clouddeploy,
    google_project_iam_member.batch_approver_clouddeploy_viewer,
    google_project_iam_member.batch_approver_logs,
  ]
}
