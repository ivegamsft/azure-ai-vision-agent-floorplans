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
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.0"
  suffix  = [random_string.suffix.result]
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = module.naming.resource_group.name_unique
  location = var.location

  tags = {
    environment = var.environment
    workload    = "floorplans"
  }
}

# Storage Account Module
module "storage" {
  source              = "./modules/storage"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  unique_suffix       = local.resource_suffix
  resource_token      = module.naming.storage_account.name_unique
}

# Application Insights Module
module "appinsights" {
  source              = "./modules/appinsights"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  resource_token      = module.naming.application_insights.name_unique
  log_analytics_token = module.naming.log_analytics_workspace.name_unique
}

# Azure Vision Module
module "vision" {
  source              = "./modules/vision"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  resource_token      = module.naming.cognitive_account.name_unique
  sku_name            = var.vision_sku_name
}

# Azure OpenAI Module
module "openai" {
  source              = "./modules/openai"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  resource_token      = module.naming.cognitive_account.name_unique
  sku_name            = var.openai_sku_name
}

# Key Vault Module - Create before apps to store secrets
module "keyvault" {
  source              = "./modules/keyvault"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  resource_token      = module.naming.key_vault.name_unique

  secrets = {
    "storage-connection-string" = {
      value        = module.storage.outputs.storage_account.primary_connection_string
      content_type = "text/plain"
    }
    "appinsights-connection-string" = {
      value        = module.appinsights.outputs.connection_string
      content_type = "text/plain"
    }
    "vision-endpoint" = {
      value        = module.vision.outputs.endpoint
      content_type = "text/plain"
    }
    "vision-key" = {
      value        = module.vision.outputs.key
      content_type = "text/plain"
    }
    "openai-endpoint" = {
      value        = module.openai.outputs.endpoint
      content_type = "text/plain"
    }
    "openai-key" = {
      value        = module.openai.outputs.key
      content_type = "text/plain"
    }
  }
}

//TODO: Move to a role assignment module and pass in the role and principal_id as variables
# Add current user as Key Vault Administrator
resource "azurerm_role_assignment" "current_user_kv_admin" {
  scope                = module.keyvault.outputs.key_vault_id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

//TODO: Move to a role assignment module and pass in the role and principal_id as variables
# Add any additional Key Vault Administrators from variables
resource "azurerm_role_assignment" "additional_kv_admins" {
  for_each = toset(var.key_vault_admins)

  scope                = module.keyvault.outputs.key_vault_id
  role_definition_name = "Key Vault Administrator"
  principal_id         = each.value
}

# Azure Function Module
module "function" {
  source                 = "./modules/function"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = var.location
  unique_suffix          = local.resource_suffix
  key_vault_id           = module.keyvault.outputs.key_vault_uri
  resource_token         = module.naming.function_app.name_unique
  app_service_plan_token = "${module.naming.app_service_plan.name_unique}-func"

  depends_on = [module.keyvault]
}

# Web App Module
module "webapp" {
  source                 = "./modules/webapp"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = var.location
  unique_suffix          = local.resource_suffix
  key_vault_id           = module.keyvault.outputs.key_vault_uri
  function_url           = module.function.outputs.function_url
  resource_token         = module.naming.app_service.name_unique
  app_service_plan_token = "${module.naming.app_service_plan.name_unique}-web"

  depends_on = [module.keyvault, module.function]
}

//TODO: Move to a role assignment module and pass in the role and principal_id as variables
# Update Key Vault with app identities
resource "azurerm_role_assignment" "function_kv_access" {
  scope                = module.keyvault.outputs.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.function.outputs.principal_id
}

//TODO: Move to a role assignment module and pass in the role and principal_id as variables
resource "azurerm_role_assignment" "webapp_kv_access" {
  scope                = module.keyvault.outputs.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.webapp.outputs.principal_id
}

# Root outputs
output "deployment_info" {
  sensitive = true
  value = {
    resource_group_info = {
      name     = azurerm_resource_group.rg.name
      location = azurerm_resource_group.rg.location
    }
    storage_info = {
      name                      = module.storage.outputs.storage_account.name
      primary_connection_string = module.storage.outputs.storage_account.primary_connection_string
    }
    application_insights = {
      instrumentation_key = module.appinsights.outputs.instrumentation_key
      connection_string   = module.appinsights.outputs.connection_string
    }
    vision = {
      endpoint = module.vision.outputs.endpoint
      key      = module.vision.outputs.key
    }
    openai = {
      endpoint = module.openai.outputs.endpoint
      key      = module.openai.outputs.key
    }
    function = {
      name         = module.function.outputs.app_id
      url          = module.function.outputs.function_url
      principal_id = module.function.outputs.principal_id
    }
    webapp = {
      name         = module.webapp.outputs.app_id
      url          = module.webapp.outputs.webapp_url
      principal_id = module.webapp.outputs.principal_id
    }
    key_vault = {
      id  = module.keyvault.outputs.key_vault_id
      uri = module.keyvault.outputs.key_vault_uri
    }
  }
}
