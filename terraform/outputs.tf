output "github_workload_identity_provider" {
  value = google_iam_workload_identity_pool_provider.github.name
}

output "github_deployer_service_account" {
  value = google_service_account.github_deployer.email
}

output "deploy_project_id" {
  value = var.deploy_project_id
}

output "artifact_project_id" {
  value = var.artifact_project_id
}

output "region" {
  value = var.region
}

output "delivery_pipelines" {
  value = sort(tolist(local.services))
}

output "artifact_registry_repository" {
  value = google_artifact_registry_repository.applications.name
}

output "cloud_build_service_account" {
  value = google_service_account.cloud_build_builder.email
}
