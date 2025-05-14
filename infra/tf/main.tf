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

# Resource Group for all resources
resource "azurerm_resource_group" "rg" {
  name     = module.naming.resource_group.name_unique
  location = var.location
  tags     = local.common_tags
}

# Storage Account Module - Compute region
module "storage" {
  source              = "./modules/storage"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  unique_suffix       = local.resource_suffix
  resource_token      = module.naming.storage_account.name_unique
  role_assignments = [
    {
      role_definition_name = "Storage Blob Data Contributor"
      principal_id         = module.function.identity.principal_id
    }
  ]
}


# Azure OpenAI for AI Foundry
module "aifoundry" {
  source              = "./modules/aifoundry"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.ai_services_location
  resource_token      = "${module.naming.cognitive_account.name_unique}-aifoundry"
  tags                = local.common_tags
}

# GPT-4 Model Deployment for AI Foundry
module "aifoundry_project" {
  source            = "./modules/aifoundry-project"
  project_token     = "${module.naming.cognitive_account.name_unique}-gpt4"
  openai_account_id = module.aifoundry.outputs.id
  model_name        = "gpt-4"
  model_version     = "turbo-2024-04-09"
}

# RBAC for Azure OpenAI - both function app and current user
module "aifoundry_rbac" {
  for_each = toset([
    module.function.identity.principal_id,
    data.azurerm_client_config.current.object_id
  ])
  source               = "./modules/rbac"
  scope                = module.aifoundry.outputs.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = each.key
  depends_on           = [module.aifoundry, module.function]
}

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
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.ai_services_location
  resource_token      = module.naming.cognitive_account.name_unique
}

# RBAC for OpenAI service - both function app and current user
module "openai_rbac" {
  for_each = toset([
    module.function.identity.principal_id,
    data.azurerm_client_config.current.object_id
  ])
  source               = "./modules/rbac"
  scope                = module.openai.openai.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = each.key
  depends_on           = [module.openai, module.function]
}

# Vision Module - AI Services region
module "vision" {
  source              = "./modules/vision"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.vision_ai_services_location
  resource_token      = "${module.naming.cognitive_account.name_unique}-vision"
  sku_name            = var.vision_sku_name
  prediction_sku_name = var.vision_prediction_sku_name
  training_sku_name   = var.vision_training_sku_name
}

# RBAC for Vision service - both function app and current user
module "vision_rbac" {
  for_each = toset([
    module.function.identity.principal_id,
    data.azurerm_client_config.current.object_id
  ])
  source               = "./modules/rbac"
  scope                = module.vision.outputs.id
  role_definition_name = "Cognitive Services Custom Vision Contributor"
  principal_id         = each.key
  depends_on           = [module.vision, module.function]
}

# Key Vault Module - Compute region
module "keyvault" {
  source              = "./modules/keyvault"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  resource_token      = module.naming.key_vault.name_unique
}

# RBAC for Key Vault - both function app and current user
module "keyvault_rbac" {
  for_each = toset([
    module.function.identity.principal_id,
    data.azurerm_client_config.current.object_id
  ])
  source               = "./modules/rbac"
  scope                = module.keyvault.outputs.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.key
  depends_on           = [module.keyvault, module.function]
}

# Function storage account - Compute region
module "function_storage" {
  source              = "./modules/storage"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  unique_suffix       = "${local.resource_suffix}-func"
  resource_token      = "${module.naming.storage_account.name_unique}func"
  # We'll assign roles separately to break the circular dependency
  role_assignments = []
}

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
  role_assignments = [
    {
      scope                = module.storage.outputs.id
      role_definition_name = "Storage Blob Data Contributor"
    },
    {
      scope                = module.keyvault.outputs.key_vault_id
      role_definition_name = "Key Vault Secrets User"
    }
  ]
  depends_on = [module.keyvault, module.function_storage]
}

# Storage blob access for function app
module "function_storage_rbac" {
  source               = "./modules/rbac"
  scope                = module.function_storage.outputs.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = module.function.identity.principal_id
  depends_on           = [module.function, module.function_storage]
}

# Storage blob access for primary storage account
module "storage_rbac" {
  source               = "./modules/rbac"
  scope                = module.storage.outputs.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.function.identity.principal_id
  depends_on           = [module.storage, module.function]
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
  role_assignments = [
    {
      scope                = module.storage.outputs.id
      role_definition_name = "Storage Blob Data Contributor"
    },
    {
      scope                = module.keyvault.outputs.key_vault_id
      role_definition_name = "Key Vault Secrets User"
    }
  ]
  depends_on = [module.keyvault, module.function]
}

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
    "vision-prediction-endpoint" = {
      value        = module.vision.prediction.endpoint
      content_type = "text/plain"
      tags = {
        purpose = "Vision Prediction API access"
      }
    }
    "vision-prediction-key" = {
      value        = module.vision.prediction.key
      content_type = "text/plain"
      tags = {
        purpose = "Vision Prediction API access"
      }
    }
    "vision-training-endpoint" = {
      value        = module.vision.training.endpoint
      content_type = "text/plain"
      tags = {
        purpose = "Vision Training API access"
      }
    }
    "vision-training-key" = {
      value        = module.vision.training.key
      content_type = "text/plain"
      tags = {
        purpose = "Vision Training API access"
      }
    }
  }
}
