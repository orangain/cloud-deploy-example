output "github_workload_identity_provider" {
  value = google_iam_workload_identity_pool_provider.github.name
}

output "github_deployer_service_account" {
  value = google_service_account.github_deployer.email
}

output "deploy_project_id" {
  value = var.deploy_project_id
}

output "region" {
  value = var.region
}

output "delivery_pipelines" {
  value = sort(tolist(var.services))
}

