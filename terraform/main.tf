locals {
  services = toset([
    "hello-service",
    "hello-function",
    "hello-ko-service",
  ])

  runtime_projects = {
    stg  = var.staging_project_id
    prod = var.production_project_id
  }

  deploy_apis = toset([
    "artifactregistry.googleapis.com",
    "binaryauthorization.googleapis.com",
    "cloudbuild.googleapis.com",
    "clouddeploy.googleapis.com",
    "containeranalysis.googleapis.com",
    "containerscanning.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "pubsub.googleapis.com",
    "sts.googleapis.com",
    "storage.googleapis.com",
  ])

  runtime_apis = toset([
    "artifactregistry.googleapis.com",
    "binaryauthorization.googleapis.com",
    "cloudbuild.googleapis.com",
    "logging.googleapis.com",
    "run.googleapis.com",
  ])

  targets = merge([
    for service in local.services : {
      for environment, project_id in local.runtime_projects :
      "${service}-${environment}" => {
        service     = service
        environment = environment
        project_id  = project_id
      }
    }
  ]...)
}
