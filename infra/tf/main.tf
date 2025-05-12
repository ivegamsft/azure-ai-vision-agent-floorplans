# Get current client configuration
data "azurerm_client_config" "current" {}

# Random string for unique names
resource "random_string" "suffix" {
  length  = 8
  special = false
  lower   = true
  upper   = false
  numeric = true
}

locals {
  resource_suffix = random_string.suffix.result
  common_tags = {
    environment = var.environment
    workload    = "floorplans"
  }
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.0"
  suffix  = [random_string.suffix.result]
}

# Resource Group for compute resources
resource "azurerm_resource_group" "rg" {
  name     = "${module.naming.resource_group.name_unique}-compute"
  location = var.location
  tags     = local.common_tags
}

# Resource Group for AI services
resource "azurerm_resource_group" "rg_ai" {
  name     = "${module.naming.resource_group.name_unique}-ai"
  location = var.ai_services_location
  tags     = local.common_tags
}

# Storage Account Module - Compute region
module "storage" {
  source              = "./modules/storage"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  unique_suffix       = local.resource_suffix
  resource_token      = module.naming.storage_account.name_unique
}

//TODO: Add a module to add rbac roles to the storage account

# Application Insights Module - Compute region
module "appinsights" {
  source              = "./modules/appinsights"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  resource_token      = module.naming.application_insights.name_unique
  log_analytics_token = module.naming.log_analytics_workspace.name_unique
}

# Azure OpenAI Module - AI Services region
module "openai" {
  source              = "./modules/openai"
  resource_group_name = azurerm_resource_group.rg_ai.name
  location            = var.ai_services_location
  resource_token      = module.naming.cognitive_account.name_unique
}

# Vision Module - AI Services region
module "vision" {
  source              = "./modules/vision"
  resource_group_name = azurerm_resource_group.rg_ai.name
  location            = var.vision_ai_services_location
  resource_token      = "${module.naming.cognitive_account.name_unique}-vision"
  sku_name            = var.vision_sku_name
}

# Key Vault Module - Compute region
module "keyvault" {
  source              = "./modules/keyvault"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  resource_token      = module.naming.key_vault.name_unique
}

# Function storage account - Compute region
module "function_storage" {
  source              = "./modules/storage"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  unique_suffix       = "${local.resource_suffix}-func"
  resource_token      = "${module.naming.storage_account.name_unique}func"
}

//TODO: Add a module to add rbac roles to the function storage account

# Function App Module - Compute region
module "function" {
  source                             = "./modules/function"
  resource_group_name                = azurerm_resource_group.rg.name
  location                           = var.location
  unique_suffix                      = local.resource_suffix
  resource_token                     = module.naming.function_app.name_unique
  app_service_plan_token             = "${module.naming.app_service_plan.name_unique}-func"
  storage_account_name               = module.function_storage.outputs.storage_account_name
  storage_account_primary_access_key = module.function_storage.outputs.storage_account_primary_access_key
  key_vault_id                       = module.keyvault.outputs.key_vault_uri
  depends_on                         = [module.keyvault, module.function_storage]
}

# Web App Module - Compute region
module "webapp" {
  source                 = "./modules/webapp"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = var.location
  unique_suffix          = local.resource_suffix
  key_vault_id           = module.keyvault.outputs.key_vault_uri
  function_url           = module.function.outputs.function_app_url
  resource_token         = module.naming.app_service.name_unique
  app_service_plan_token = "${module.naming.app_service_plan.name_unique}-web"
  depends_on             = [module.keyvault, module.function]
}

//TODO: Add a module to add rbac roles to the web app

# Key Vault Secrets Module
module "keyvault_secrets" {
  source                       = "./modules/keyvault-secrets"
  key_vault_id                 = module.keyvault.outputs.key_vault_id
  dependent_role_assignment_id = module.keyvault.outputs.admin_role_assignment_id

  secrets = {
    "storage-connection-string" = {
      value        = module.storage.outputs.storage_account_connection_string
      content_type = "text/plain"
      tags = {
        purpose = "Storage access"
      }
    }
    "appinsights-connection-string" = {
      value        = module.appinsights.outputs.connection_string
      content_type = "text/plain"
      tags = {
        purpose = "Application monitoring"
      }
    }
    "vision-endpoint" = {
      value        = module.vision.outputs.endpoint
      content_type = "text/plain"
      tags = {
        purpose = "Vision API access"
      }
    }
    "vision-key" = {
      value        = module.vision.outputs.key
      content_type = "text/plain"
      tags = {
        purpose = "Vision API access"
      }
    }
    "openai-endpoint" = {
      value        = module.openai.openai.endpoint
      content_type = "text/plain"
      tags = {
        purpose = "OpenAI API access"
      }
    }
    "openai-key" = {
      value        = module.openai.openai.key
      content_type = "text/plain"
      tags = {
        purpose = "OpenAI API access"
      }
    }
  }
}
