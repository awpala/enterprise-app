terraform {
  required_version = ">= 1.9"

  required_providers {
    # azuread is configured by the caller with the `.external` aliased
    # provider instance — this module only manages resources in the Entra
    # External ID (CIAM) tenant, never in the workforce tenant.
    azuread = {
      source                = "hashicorp/azuread"
      version               = "~> 3.0"
      configuration_aliases = [azuread]
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
