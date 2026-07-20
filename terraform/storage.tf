resource "google_storage_bucket" "cloud_deploy" {
  project                     = var.deploy_project_id
  name                        = "${var.deploy_project_id}-cloud-deploy-${var.region}"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false
  depends_on                  = [google_project_service.deploy]
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
