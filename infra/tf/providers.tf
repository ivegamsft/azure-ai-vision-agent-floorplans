terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  backend "local" {}
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy = true
      recover_soft_deleted_key_vaults = true
    }
  }
  use_cli = false
  skip_provider_registration = true
  subscription_id = "844eabcc-dc96-453b-8d45-bef3d566f3f8"
  tenant_id       = "72f988bf-86f1-41af-91ab-2d7cd011db47"
  client_id       = "0b1a02ed-5adb-4c18-9785-045fb6277267"
}