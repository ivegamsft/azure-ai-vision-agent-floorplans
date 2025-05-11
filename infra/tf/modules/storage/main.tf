variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "unique_suffix" {
  description = "Unique suffix for resource names"
  type        = string
}

variable "resource_token" {
  description = "The token to use for storage account naming from the naming module"
  type        = string
}

resource "azurerm_storage_account" "storage" {
  name                     = var.resource_token
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  identity {
    type = "SystemAssigned"
  }

  # Enable required features for durable functions
  table_encryption_key_type = "Account"
  queue_encryption_key_type = "Account"
  is_hns_enabled            = false
  min_tls_version           = "TLS1_2"

  blob_properties {
    cors_rule {
      allowed_headers    = ["*"]
      allowed_methods    = ["GET", "POST", "PUT"]
      allowed_origins    = ["*"]
      exposed_headers    = ["*"]
      max_age_in_seconds = 3600
    }
  }

  tags = {
    environment = "production"
    purpose     = "floorplans"
  }
}

resource "azurerm_storage_container" "floorplans" {
  name                  = "floorplans"
  storage_account_id    = azurerm_storage_account.storage.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "floorplans_training" {
  name                  = "floorplans-training"
  storage_account_id    = azurerm_storage_account.storage.id
  container_access_type = "private"
}

output "outputs" {
  description = "All outputs from the storage module"
  value = {
    name                               = azurerm_storage_account.storage.name
    storage_account                    = azurerm_storage_account.storage
    principal_id                       = azurerm_storage_account.storage.identity[0].principal_id
    storage_account_name               = azurerm_storage_account.storage.name
    storage_account_primary_access_key = azurerm_storage_account.storage.primary_access_key
  }
  sensitive = true
}

//TODO: Combine all outputs into a single output
output "storage_account_name" {
  value = azurerm_storage_account.storage.name
}

output "storage_account_primary_access_key" {
  value     = azurerm_storage_account.storage.primary_access_key
  sensitive = true
}

output "storage_account_connection_string" {
  value     = azurerm_storage_account.storage.primary_connection_string
  sensitive = true
}

output "storage_account" {
  value = azurerm_storage_account.storage
}
