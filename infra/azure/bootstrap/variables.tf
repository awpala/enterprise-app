variable "subscription_id" {
  description = "Azure subscription ID that will host the tfstate storage account, and which the GitHub OIDC SP will be scoped to. Required."
  type        = string
}

variable "location" {
  description = "Azure region for the tfstate resource group and storage account."
  type        = string
  default     = "eastus"
}

variable "name_suffix" {
  description = "4-6 lowercase alphanumerics used to make the tfstate storage account name globally unique."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{4,6}$", var.name_suffix))
    error_message = "name_suffix must be 4-6 lowercase alphanumeric characters."
  }
}

variable "github_owner" {
  description = "GitHub org/user that owns the repo (used in OIDC subject claims)."
  type        = string
  default     = "awpala"
}

variable "github_repo" {
  description = "GitHub repo name (used in OIDC subject claims and for gh CLI commands)."
  type        = string
  default     = "enterprise-app"
}

variable "github_environments" {
  description = "GitHub Environments that need federated credentials on the SP. Must match the 'environment:' field on each deploy job."
  type        = list(string)
  default     = ["azure-dev", "azure-production"]
}

variable "tfstate_container_name" {
  description = "Name of the blob container holding tfstate files."
  type        = string
  default     = "tfstate"
}

variable "tfstate_resource_group_name" {
  description = "Name of the resource group that holds the tfstate storage account."
  type        = string
  default     = "ea-tfstate-rg"
}

variable "oidc_app_display_name" {
  description = "Display name of the Entra ID application used by GitHub Actions for OIDC."
  type        = string
  default     = "ea-github-oidc"
}

variable "tags" {
  description = "Tags applied to the tfstate RG and storage account."
  type        = map(string)
  default = {
    project      = "ea"
    environment  = "shared"
    "managed-by" = "terraform"
    purpose      = "tfstate-and-oidc-bootstrap"
  }
}
