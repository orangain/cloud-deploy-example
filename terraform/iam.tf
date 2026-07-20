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

resource "google_service_account" "batch_approver" {
  project      = var.deploy_project_id
  account_id   = "cloud-deploy-batch-approver"
  display_name = "Cloud Deploy batch approver"
  depends_on   = [google_project_service.deploy]
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

resource "google_project_iam_member" "execution_runtime_roles" {
  for_each = {
    for pair in setproduct(keys(local.runtime_projects), [
      "roles/run.admin",
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
  role    = "roles/cloudbuild.builds.approver"
  member  = each.value
}

resource "google_service_account_iam_member" "github_uses_execution" {
  service_account_id = google_service_account.deploy_execution.name
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.github_deployer.member
}

resource "google_project_iam_member" "batch_approver_clouddeploy" {
  project = var.deploy_project_id
  role    = "roles/clouddeploy.approver"
  member  = google_service_account.batch_approver.member
}

resource "google_project_iam_member" "batch_approver_clouddeploy_viewer" {
  project = var.deploy_project_id
  role    = "roles/clouddeploy.viewer"
  member  = google_service_account.batch_approver.member
}

resource "google_project_iam_member" "batch_approver_logs" {
  project = var.deploy_project_id
  role    = "roles/logging.logWriter"
  member  = google_service_account.batch_approver.member
}
