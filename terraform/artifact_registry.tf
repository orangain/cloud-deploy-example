data "google_project" "deploy" {
  project_id = var.deploy_project_id
}

data "google_project" "runtime" {
  for_each   = local.runtime_projects
  project_id = each.value
}

resource "google_artifact_registry_repository" "applications" {
  project       = var.artifact_project_id
  location      = var.region
  repository_id = "cloud-deploy-example"
  description   = "Application container images built by Cloud Build"
  format        = "DOCKER"

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    google_project_service.deploy,
    google_project_service.artifact,
  ]
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

resource "google_project_iam_member" "github_artifact_occurrences_reader" {
  count = var.artifact_project_id == var.deploy_project_id ? 0 : 1

  project = var.artifact_project_id
  role    = "roles/containeranalysis.occurrences.viewer"
  member  = google_service_account.github_deployer.member

  depends_on = [google_project_service.artifact]
}

resource "google_project_iam_member" "cloud_build_artifact_occurrences_editor" {
  count = var.artifact_project_id == var.deploy_project_id ? 0 : 1

  project = var.artifact_project_id
  role    = "roles/containeranalysis.occurrences.editor"
  member  = "serviceAccount:service-${data.google_project.deploy.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"

  depends_on = [google_project_service.artifact]
}

resource "google_project_iam_member" "runtime_artifact_occurrences_reader" {
  for_each = var.artifact_project_id == var.deploy_project_id ? {} : data.google_project.runtime

  project = var.artifact_project_id
  role    = "roles/containeranalysis.occurrences.viewer"
  member  = "serviceAccount:service-${each.value.number}@gcp-sa-binaryauthorization.iam.gserviceaccount.com"

  depends_on = [google_project_service.artifact]
}
