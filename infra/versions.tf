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

  # Partial backend config — concrete values come from -backend-config=...
  # at init time. The same terraform config then works for:
  #
  #   Local dev (dev state):
  #     terraform init \
  #       -backend-config=resource_group_name=<tfstate_rg> \
  #       -backend-config=storage_account_name=<tfstate_account> \
  #       -backend-config=container_name=tfstate \
  #       -backend-config=key=dev.tfstate
  #
  #   CI (dev or production — workflow chooses the key):
  #     Same flags, with key=dev.tfstate or key=production.tfstate.
  #
  # Both use_oidc and use_azuread_auth are on so the backend talks to the
  # storage account using AAD (GitHub OIDC in CI, az CLI user locally) —
  # no account keys, no SAS tokens.
  backend "azurerm" {
    use_oidc         = true
    use_azuread_auth = true
  }
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
