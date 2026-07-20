locals {
  runtime_projects = {
    stg  = var.staging_project_id
    prod = var.production_project_id
  }

  deploy_apis = toset([
    "cloudbuild.googleapis.com",
    "clouddeploy.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "storage.googleapis.com",
  ])

  runtime_apis = toset([
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "logging.googleapis.com",
    "run.googleapis.com",
  ])

  targets = merge([
    for service in var.services : {
      for environment, project_id in local.runtime_projects :
      "${service}-${environment}" => {
        service     = service
        environment = environment
        project_id  = project_id
      }
    }
  ]...)
}

resource "google_project_service" "deploy" {
  for_each           = local.deploy_apis
  project            = var.deploy_project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_project_service" "runtime" {
  for_each = {
    for pair in setproduct(keys(local.runtime_projects), local.runtime_apis) :
    "${pair[0]}/${pair[1]}" => {
      project = local.runtime_projects[pair[0]]
      api     = pair[1]
    }
  }

  project            = each.value.project
  service            = each.value.api
  disable_on_destroy = false
}

resource "google_service_account" "deploy_execution" {
  project      = var.deploy_project_id
  account_id   = "cloud-deploy-execution"
  display_name = "Cloud Deploy execution"
  depends_on   = [google_project_service.deploy]
}

resource "google_service_account" "github_deployer" {
  project      = var.deploy_project_id
  account_id   = "github-cloud-deploy"
  display_name = "GitHub Actions Cloud Deploy"
  depends_on   = [google_project_service.deploy]
}

resource "google_storage_bucket" "cloud_deploy" {
  project                     = var.deploy_project_id
  name                        = "${var.deploy_project_id}-cloud-deploy-${var.region}"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false
  depends_on                  = [google_project_service.deploy]
}

resource "google_project_iam_member" "execution_job_runner" {
  project = var.deploy_project_id
  role    = "roles/clouddeploy.jobRunner"
  member  = google_service_account.deploy_execution.member
}

resource "google_project_iam_member" "execution_automation_releaser" {
  project = var.deploy_project_id
  role    = "roles/clouddeploy.releaser"
  member  = google_service_account.deploy_execution.member
}

resource "google_service_account_iam_member" "automation_uses_execution" {
  service_account_id = google_service_account.deploy_execution.name
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.deploy_execution.member
}

resource "google_storage_bucket_iam_member" "execution_artifacts" {
  bucket = google_storage_bucket.cloud_deploy.name
  role   = "roles/storage.admin"
  member = google_service_account.deploy_execution.member
}

resource "google_storage_bucket_iam_member" "github_source_staging" {
  bucket = google_storage_bucket.cloud_deploy.name
  role   = "roles/storage.admin"
  member = google_service_account.github_deployer.member
}

resource "google_project_iam_member" "execution_runtime_roles" {
  for_each = {
    for pair in setproduct(keys(local.runtime_projects), [
      "roles/run.developer",
      "roles/iam.serviceAccountUser",
      ]) : "${pair[0]}/${pair[1]}" => {
      project = local.runtime_projects[pair[0]]
      role    = pair[1]
    }
  }

  project = each.value.project
  role    = each.value.role
  member  = google_service_account.deploy_execution.member
}

resource "google_project_iam_member" "github_roles" {
  for_each = toset([
    "roles/clouddeploy.releaser",
    "roles/clouddeploy.viewer",
  ])

  project = var.deploy_project_id
  role    = each.value
  member  = google_service_account.github_deployer.member
}

resource "google_project_iam_member" "production_approver" {
  for_each = var.production_approvers

  project = var.deploy_project_id
  role    = "roles/clouddeploy.approver"
  member  = each.value
}

resource "google_service_account_iam_member" "github_uses_execution" {
  service_account_id = google_service_account.deploy_execution.name
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.github_deployer.member
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.deploy_project_id
  workload_identity_pool_id = var.github_pool_id
  display_name              = "GitHub Actions"
  depends_on                = [google_project_service.deploy]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.deploy_project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }
  attribute_condition = "assertion.repository == '${var.github_repository}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "github_wif" {
  service_account_id = google_service_account.github_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}

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
    usages           = ["RENDER", "DEPLOY"]
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
      profiles  = []
    }
    stages {
      target_id = google_clouddeploy_target.service["${each.value}-prod"].name
      profiles  = []
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
