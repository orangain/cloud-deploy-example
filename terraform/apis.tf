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

resource "google_project_service" "artifact" {
  for_each = var.artifact_project_id == var.deploy_project_id ? toset([]) : toset([
    "artifactregistry.googleapis.com",
    "containeranalysis.googleapis.com",
    "containerscanning.googleapis.com",
  ])

  project            = var.artifact_project_id
  service            = each.value
  disable_on_destroy = false
}
