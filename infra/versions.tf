terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.14"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # NOTE: State is local for MVP. To migrate to azurerm backend later:
  #
  #   backend "azurerm" {
  #     resource_group_name  = "tfstate-rg"
  #     storage_account_name = "eatfstate<suffix>"
  #     container_name       = "tfstate"
  #     key                  = "dev.tfstate"
  #     use_oidc             = true
  #   }
  #
  # Then run:  terraform init -migrate-state
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy          = true
      purge_soft_deleted_secrets_on_destroy = true
      recover_soft_deleted_key_vaults       = true
    }
  }
  subscription_id = var.subscription_id
}

provider "random" {}
