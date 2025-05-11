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

# Get the storage account from the storage module
variable "storage_account_name" {
  description = "Name of the storage account for function app"
  type        = string
}

variable "storage_account_primary_access_key" {
  description = "Primary access key of the storage account"
  type        = string
  sensitive   = true
}

resource "azurerm_storage_table" "durable_task_hub" {
  name                 = "DurableTaskHub"
  storage_account_name = var.storage_account_name
}

resource "azurerm_storage_table" "durable_history" {
  name                 = "History"
  storage_account_name = var.storage_account_name
}

resource "azurerm_storage_table" "durable_instances" {
  name                 = "Instances"
  storage_account_name = var.storage_account_name
}

resource "azurerm_service_plan" "function_plan" {
  name                = var.app_service_plan_token
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "B1" # Basic tier
}

resource "azurerm_linux_function_app" "function" {
  name                       = var.resource_token
  resource_group_name        = var.resource_group_name
  location                   = var.location
  service_plan_id            = azurerm_service_plan.function_plan.id
  storage_account_name       = var.storage_account_name
  storage_account_access_key = var.storage_account_primary_access_key

  site_config {
    application_stack {
      python_version = "3.10"
    }
    cors {
      allowed_origins = ["*"]
    }
    app_command_line = "python -m azure.functions.durable"
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "ENABLE_ORYX_BUILD"                  = "true"
    "SCM_DO_BUILD_DURING_DEPLOYMENT"     = "true"
    "FUNCTIONS_WORKER_RUNTIME"           = "python"
    "AzureWebJobsStorage"                = "DefaultEndpointsProtocol=https;AccountName=${var.storage_account_name};AccountKey=${var.storage_account_primary_access_key};EndpointSuffix=core.windows.net"
    "WEBSITE_MOUNT_ENABLED"              = "1"
    "PYTHON_ISOLATE_WORKER_DEPENDENCIES" = "1"
  }

  depends_on = [azurerm_storage_table.durable_task_hub, azurerm_storage_table.durable_history, azurerm_storage_table.durable_instances]
}

output "name" {
  description = "Name of the function app"
  value       = azurerm_linux_function_app.function.name
}

output "principal_id" {
  description = "Principal ID of the function app's managed identity"
  value       = azurerm_linux_function_app.function.identity[0].principal_id
}

output "default_hostname" {
  description = "Default hostname of the function app"
  value       = azurerm_linux_function_app.function.default_hostname
}

output "function_app_url" {
  description = "URL of the function app"
  value       = "https://${azurerm_linux_function_app.function.default_hostname}"
}
