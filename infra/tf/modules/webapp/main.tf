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

variable "function_url" {
  description = "Azure Function app URL"
  type        = string
}

variable "resource_token" {
  description = "The token to use for Web App naming from the naming module"
  type        = string
}

variable "app_service_plan_token" {
  description = "The token to use for App Service Plan naming from the naming module"
  type        = string
}

resource "azurerm_service_plan" "webapp_plan" {
  name                = var.app_service_plan_token
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "P1v3"
}

resource "azurerm_linux_web_app" "webapp" {
  name                = var.resource_token
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = azurerm_service_plan.webapp_plan.id

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
    "STORAGE_CONN_STR"               = "@Microsoft.KeyVault(SecretUri=${var.key_vault_id}/secrets/storage-connection-string)"
    "CONTAINER_NAME"                 = "floorplans"
    "FUNCTION_START_URL"             = "${var.function_url}/api/orchestrators/vision_agent_orchestrator"
    "VISION_ENDPOINT"                = "@Microsoft.KeyVault(SecretUri=${var.key_vault_id}/secrets/vision-endpoint)"
    "VISION_KEY"                     = "@Microsoft.KeyVault(SecretUri=${var.key_vault_id}/secrets/vision-key)"
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
    "WEBSITES_PORT"                  = "8501"
  }
}

output "outputs" {
  description = "All outputs from the Web App module"
  value = {
    webapp_url   = "https://${azurerm_linux_web_app.webapp.default_hostname}"
    principal_id = azurerm_linux_web_app.webapp.identity[0].principal_id
    app_id       = azurerm_linux_web_app.webapp.name
  }
}
