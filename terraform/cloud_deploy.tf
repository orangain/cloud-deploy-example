resource "google_clouddeploy_target" "service" {
  for_each = local.targets

  project          = var.deploy_project_id
  location         = var.region
  name             = each.key
  description      = "${each.value.service} ${each.value.environment}"
  require_approval = each.value.environment == "prod"

  run {
    location = "projects/${each.value.project_id}/locations/${var.region}"
  }

  execution_configs {
    usages           = ["RENDER", "DEPLOY", "VERIFY"]
    service_account  = google_service_account.deploy_execution.email
    artifact_storage = "gs://${google_storage_bucket.cloud_deploy.name}"
  }

  depends_on = [
    google_project_service.deploy,
    google_project_service.runtime,
    google_project_iam_member.execution_runtime_roles,
  ]
}

resource "google_clouddeploy_delivery_pipeline" "service" {
  for_each = var.services

  project     = var.deploy_project_id
  location    = var.region
  name        = each.value
  description = "Deploy ${each.value} from staging to production"

  serial_pipeline {
    stages {
      target_id = google_clouddeploy_target.service["${each.value}-stg"].name
      profiles  = ["stg"]

      strategy {
        standard {
          verify = true
        }
      }
    }
    stages {
      target_id = google_clouddeploy_target.service["${each.value}-prod"].name
      profiles  = ["prod"]

      strategy {
        standard {
          verify = true
        }
      }
    }
  }
}

resource "google_clouddeploy_automation" "promote_to_prod" {
  for_each = var.services

  project           = var.deploy_project_id
  location          = var.region
  name              = "promote-to-prod"
  delivery_pipeline = google_clouddeploy_delivery_pipeline.service[each.value].name
  service_account   = google_service_account.deploy_execution.email
  description       = "Promote ${each.value} to production after a successful staging rollout"

  selector {
    targets {
      id = google_clouddeploy_target.service["${each.value}-stg"].name
    }
  }

  rules {
    promote_release_rule {
      id                    = "promote-to-prod"
      destination_target_id = google_clouddeploy_target.service["${each.value}-prod"].name
    }
  }

  depends_on = [
    google_project_iam_member.execution_automation_releaser,
    google_service_account_iam_member.automation_uses_execution,
  ]
}
