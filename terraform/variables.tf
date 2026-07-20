variable "deploy_project_id" {
  description = "Cloud Deploy control project."
  type        = string
  default     = "orange-sandbox"
}

variable "staging_project_id" {
  description = "Staging Cloud Run project."
  type        = string
  default     = "cloud-deploy-example-stg"
}

variable "production_project_id" {
  description = "Production Cloud Run project."
  type        = string
  default     = "cloud-deploy-example-prod"
}

variable "region" {
  description = "Cloud Deploy and Cloud Run region."
  type        = string
  default     = "asia-northeast1"
}

variable "services" {
  description = "Service names; each must match an apps/<name> directory."
  type        = set(string)
  default     = ["hello-service", "hello-function"]

  validation {
    condition     = alltrue([for name in var.services : can(regex("^[a-z][a-z0-9-]{0,48}$", name))])
    error_message = "Service names must be valid Cloud Run service names."
  }
}

variable "github_repository" {
  description = "GitHub repository in owner/name form."
  type        = string
}

variable "github_pool_id" {
  description = "Workload Identity Pool ID."
  type        = string
  default     = "github-actions"
}

variable "production_approvers" {
  description = "IAM members allowed to approve production rollouts, for example group:release-managers@example.com."
  type        = set(string)
  default     = []
}
