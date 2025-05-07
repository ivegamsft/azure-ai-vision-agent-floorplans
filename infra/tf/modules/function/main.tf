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

variable "key_vault_id" {
  description = "ID of the Key Vault to store secrets"
  type        = string
}

variable "resource_token" {
  description = "The token to use for Function App naming from the naming module"
  type        = string
}

variable "app_service_plan_token" {
  description = "The token to use for App Service Plan naming from the naming module"
  type        = string
}

# Storage account for Function App
//TODO: Move this to main.tf and use the storage module, add variables for storage account name and resource group name
resource "azurerm_storage_account" "function_storage" {
  name                     = "${replace(var.resource_token, "-", "")}func"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "plan" {
  name                = var.app_service_plan_token
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "P1v3"
}

resource "azurerm_linux_function_app" "function" {
  name                       = var.resource_token
  resource_group_name        = var.resource_group_name
  location                   = var.location
  service_plan_id            = azurerm_service_plan.plan.id
  storage_account_name       = azurerm_storage_account.function_storage.name
  storage_account_access_key = azurerm_storage_account.function_storage.primary_access_key

  site_config {
    application_stack {
      python_version = "3.9"
    }
    cors {
      allowed_origins = ["*"]
    }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"              = "python"
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = "@Microsoft.KeyVault(SecretUri=${var.key_vault_id}/secrets/appinsights-connection-string)"
    "BLOB_CONNECTION_STRING"                = "@Microsoft.KeyVault(SecretUri=${var.key_vault_id}/secrets/storage-connection-string)"
    "CV_ENDPOINT"                           = "@Microsoft.KeyVault(SecretUri=${var.key_vault_id}/secrets/vision-endpoint)"
    "CV_KEY"                                = "@Microsoft.KeyVault(SecretUri=${var.key_vault_id}/secrets/vision-key)"
  }
}

output "outputs" {
  description = "All outputs from the Function module"
  value = {
    function_url = "https://${azurerm_linux_function_app.function.default_hostname}"
    principal_id = azurerm_linux_function_app.function.identity[0].principal_id
    app_id       = azurerm_linux_function_app.function.id
  }
}
