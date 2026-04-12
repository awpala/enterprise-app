terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.14"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # State is intentionally LOCAL for this bootstrap module. It creates the
  # remote backend that the root infra uses; it can't depend on itself.
  # The tfstate file is gitignored (see .gitignore in this folder).
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = var.subscription_id
}

provider "azuread" {
  # Tenant auto-detected from az CLI. Override with ARM_TENANT_ID if needed.
}

provider "random" {}
