# This module manages the Azure OpenAI account for AI Foundry

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_token" {
  description = "The token to use for Azure OpenAI account naming"
  type        = string
}

variable "sku_name" {
  description = "The SKU of the Azure OpenAI account"
  type        = string
  default     = "S0"
}

variable "tags" {
  description = "Tags to apply to the Azure OpenAI account"
  type        = map(string)
  default     = {}
}

resource "azurerm_cognitive_account" "aifoundry" {
  name                          = var.resource_token
  resource_group_name           = var.resource_group_name
  location                      = var.location
  kind                          = "OpenAI"
  sku_name                      = var.sku_name
  tags                          = var.tags
  custom_subdomain_name         = lower(var.resource_token)
  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }
}

output "outputs" {
  description = "All outputs from the Azure OpenAI account"
  value = {
    id           = azurerm_cognitive_account.aifoundry.id
    principal_id = azurerm_cognitive_account.aifoundry.identity[0].principal_id
    endpoint     = azurerm_cognitive_account.aifoundry.endpoint
  }
  sensitive = true
}
