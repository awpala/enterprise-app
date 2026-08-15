variable "aws_region" {
  description = "AWS region for the Terraform state bucket."
  type        = string
  default     = "us-east-1"
}

variable "name_suffix" {
  description = "Lowercase suffix used to make the state bucket globally unique."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{4,10}$", var.name_suffix))
    error_message = "name_suffix must contain 4-10 lowercase letters or digits."
  }
}

variable "github_owner" {
  description = "GitHub organization or user that owns the repository."
  type        = string
  default     = "awpala"
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
  default     = "enterprise-app"
}

variable "github_environments" {
  description = "GitHub Environments permitted to assume the deployment role."
  type        = set(string)
  default     = ["aws-dev", "aws-production"]
}

variable "existing_github_oidc_provider_arn" {
  description = "Existing account-level GitHub Actions OIDC provider ARN to reuse instead of creating one."
  type        = string
  default     = null
  nullable    = true
}

variable "tags" {
  description = "Tags applied to bootstrap resources."
  type        = map(string)
  default = {
    project      = "ea"
    environment  = "shared"
    "managed-by" = "terraform"
    cloud        = "aws"
    purpose      = "tfstate-and-oidc-bootstrap"
  }
}
