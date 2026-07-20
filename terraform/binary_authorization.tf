resource "google_binary_authorization_policy" "runtime" {
  for_each = local.runtime_projects

  project     = each.value
  description = "Allow only images verified by orange-sandbox Cloud Build."

  default_admission_rule {
    evaluation_mode         = "REQUIRE_ATTESTATION"
    enforcement_mode        = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    require_attestations_by = ["projects/${var.deploy_project_id}/attestors/built-by-cloud-build"]
  }

  global_policy_evaluation_mode = "ENABLE"

  depends_on = [google_project_service.runtime]
}

resource "google_project_iam_member" "runtime_verifies_cloud_build_attestor" {
  for_each = data.google_project.runtime

  project = var.deploy_project_id
  role    = "roles/binaryauthorization.attestorsVerifier"
  member  = "serviceAccount:service-${each.value.number}@gcp-sa-binaryauthorization.iam.gserviceaccount.com"

  depends_on = [
    google_project_service.deploy,
    google_project_service.runtime,
  ]
}
