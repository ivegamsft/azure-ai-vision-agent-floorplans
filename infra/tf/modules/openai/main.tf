variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
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

resource "azurerm_cognitive_account" "openai" {
  name                = var.resource_token
  resource_group_name = var.resource_group_name
  location            = "swedencentral"  # Using Sweden Central since it supports GPT-4V
  kind                = "OpenAI"
  sku_name            = var.sku_name

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_cognitive_deployment" "gpt4v" {
  name                 = "gpt-4v"
  cognitive_account_id = azurerm_cognitive_account.openai.id
  model {
    format  = "OpenAI"
    name    = "gpt-4"
    version = "vision-preview"
  }

  scale {
    type = "Standard"
  }
}

output "outputs" {
  description = "All outputs from the OpenAI module"
  value = {
    endpoint     = azurerm_cognitive_account.openai.endpoint
    key          = azurerm_cognitive_account.openai.primary_access_key
    principal_id = azurerm_cognitive_account.openai.identity[0].principal_id
  }
  sensitive = true
}