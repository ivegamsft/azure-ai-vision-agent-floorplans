variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region. Must be one of the supported regions for Azure Computer Vision custom models."
  type        = string
  validation {
    condition = contains([
      "westus2", "eastus", "westeurope"
    ], lower(var.location))
    error_message = "The location must be one of: West US 2, East US or West Europe."
  }
}

variable "resource_token" {
  description = "The token to use for resource naming from the naming module"
  type        = string
}

variable "sku_name" {
  description = "The SKU name for the Cognitive Services account"
  type        = string
  default     = "S1"
}

resource "azurerm_cognitive_account" "vision" {
  name                = var.resource_token
  resource_group_name = var.resource_group_name
  location            = var.location
  kind                = "ComputerVision"
  sku_name            = var.sku_name

  identity {
    type = "SystemAssigned"
  }
}

output "outputs" {
  description = "All outputs from the Vision module"
  value = {
    endpoint     = azurerm_cognitive_account.vision.endpoint
    key          = azurerm_cognitive_account.vision.primary_access_key
    principal_id = azurerm_cognitive_account.vision.identity[0].principal_id
    id          = azurerm_cognitive_account.vision.id
  }
  sensitive = true
}
