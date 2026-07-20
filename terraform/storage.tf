resource "google_storage_bucket" "cloud_deploy" {
  project                     = var.deploy_project_id
  name                        = "${var.deploy_project_id}-cloud-deploy-${var.region}"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false
  depends_on                  = [google_project_service.deploy]
}

data "google_storage_bucket" "cloud_build_source" {
  name = "${var.deploy_project_id}_cloudbuild"
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

resource "google_storage_bucket_iam_member" "github_build_source_writer" {
  bucket = data.google_storage_bucket.cloud_build_source.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.github_deployer.member
}

resource "google_storage_bucket_iam_member" "builder_source_reader" {
  bucket = data.google_storage_bucket.cloud_build_source.name
  role   = "roles/storage.objectViewer"
  member = google_service_account.cloud_build_builder.member
}
