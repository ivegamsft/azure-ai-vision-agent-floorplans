variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region. Must be one of the supported regions for Azure OpenAI."
  type        = string
  validation {
    condition = contains([
      "eastus", "westus", "francecentral", "northeurope",
      "westeurope", "southeastasia", "eastasia", "koreacentral"
    ], lower(var.location))
    error_message = "The location must be one of: East US, West US, France Central, North Europe, West Europe, South East Asia, East Asia, Korea Central."
  }
}

variable "resource_token" {
  description = "The token to use for resource naming from the naming module"
  type        = string
}

variable "sku_name" {
  description = "The SKU name for the OpenAI account"
  type        = string
  default     = "S0"
}

variable "openai_deployments" {
  description = "Map of OpenAI model deployments to create"
  type = map(object({
    name          = string,
    model_name    = string,
    model_version = string,
    capacity      = optional(number)
  }))
  default = {
    "gpt4v" = {
      name          = "gpt-4v",
      model_name    = "gpt-4",
      model_version = "vision-preview",
      capacity      = 1
    }
  }
}

resource "azurerm_cognitive_account" "openai" {
  name                = var.resource_token
  resource_group_name = var.resource_group_name
  location            = var.location
  kind                = "OpenAI"
  sku_name            = var.sku_name

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_cognitive_deployment" "deployments" {
  for_each             = var.openai_deployments
  name                 = each.value.name
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = each.value.model_name
    version = each.value.model_version
  }
  sku {
    name     = "Standard"
    capacity = try(each.value.capacity, 1)
  }

  rai_policy_name = "Microsoft.Default"
}

output "openai" {
  description = "All outputs from the OpenAI module"
  value = {
    endpoint      = azurerm_cognitive_account.openai.endpoint
    key           = azurerm_cognitive_account.openai.primary_access_key
    principal_id  = azurerm_cognitive_account.openai.identity[0].principal_id
    id            = azurerm_cognitive_account.openai.id
    deployment_id = { for k, v in azurerm_cognitive_deployment.deployments : k => v.id }
  }
  sensitive = true
}
