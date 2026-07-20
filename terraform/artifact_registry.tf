data "google_project" "runtime" {
  for_each   = local.runtime_projects
  project_id = each.value
}

resource "google_artifact_registry_repository" "applications" {
  project       = var.deploy_project_id
  location      = var.region
  repository_id = "cloud-deploy-example"
  description   = "Application container images built by Cloud Build"
  format        = "DOCKER"

  depends_on = [google_project_service.deploy]
}

resource "google_artifact_registry_repository_iam_member" "builder_writer" {
  project    = google_artifact_registry_repository.applications.project
  location   = google_artifact_registry_repository.applications.location
  repository = google_artifact_registry_repository.applications.repository_id
  role       = "roles/artifactregistry.writer"
  member     = google_service_account.cloud_build_builder.member
}

resource "google_artifact_registry_repository_iam_member" "deploy_execution_reader" {
  project    = google_artifact_registry_repository.applications.project
  location   = google_artifact_registry_repository.applications.location
  repository = google_artifact_registry_repository.applications.repository_id
  role       = "roles/artifactregistry.reader"
  member     = google_service_account.deploy_execution.member
}

resource "google_artifact_registry_repository_iam_member" "github_reader" {
  project    = google_artifact_registry_repository.applications.project
  location   = google_artifact_registry_repository.applications.location
  repository = google_artifact_registry_repository.applications.repository_id
  role       = "roles/artifactregistry.reader"
  member     = google_service_account.github_deployer.member
}

resource "google_artifact_registry_repository_iam_member" "cloud_run_reader" {
  for_each = data.google_project.runtime

  project    = google_artifact_registry_repository.applications.project
  location   = google_artifact_registry_repository.applications.location
  repository = google_artifact_registry_repository.applications.repository_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:service-${each.value.number}@serverless-robot-prod.iam.gserviceaccount.com"
}
