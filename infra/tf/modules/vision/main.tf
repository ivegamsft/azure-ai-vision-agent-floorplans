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

variable "prediction_sku_name" {
  description = "The SKU name for the Custom Vision Prediction service"
  type        = string
  default     = "F0" # Free tier by default
}

variable "training_sku_name" {
  description = "The SKU name for the Custom Vision Training service"
  type        = string
  default     = "F0" # Free tier by default
}

resource "azurerm_cognitive_account" "vision" {
  name                = "${var.resource_token}-vision"
  resource_group_name = var.resource_group_name
  location            = var.location
  kind                = "ComputerVision"
  sku_name            = var.sku_name

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_cognitive_account" "vision_prediction" {
  name                = "${var.resource_token}-prediction"
  resource_group_name = var.resource_group_name
  location            = var.location
  kind                = "CustomVision.Prediction"
  sku_name            = var.prediction_sku_name

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_cognitive_account" "vision_training" {
  name                = "${var.resource_token}-vision-training"
  resource_group_name = var.resource_group_name
  location            = var.location
  kind                = "CustomVision.Training"
  sku_name            = var.training_sku_name

  identity {
    type = "SystemAssigned"
  }
}

//TODO: Combine into one output
output "outputs" {
  description = "All outputs from the Vision module"
  value = {
    endpoint     = azurerm_cognitive_account.vision.endpoint
    key          = azurerm_cognitive_account.vision.primary_access_key
    principal_id = azurerm_cognitive_account.vision.identity[0].principal_id
    id           = azurerm_cognitive_account.vision.id
  }
  sensitive = true
}

output "endpoint" {
  description = "The endpoint of the Vision service"
  value       = azurerm_cognitive_account.vision.endpoint
  sensitive   = true
}

output "key" {
  description = "The primary access key of the Vision service"
  value       = azurerm_cognitive_account.vision.primary_access_key
  sensitive   = true
}

output "prediction" {
  description = "The Custom Vision Prediction service details"
  value = {
    endpoint     = azurerm_cognitive_account.vision_prediction.endpoint
    key          = azurerm_cognitive_account.vision_prediction.primary_access_key
    principal_id = azurerm_cognitive_account.vision_prediction.identity[0].principal_id
    id           = azurerm_cognitive_account.vision_prediction.id
  }
  sensitive = true
}

output "training" {
  description = "The Custom Vision Training service details"
  value = {
    endpoint     = azurerm_cognitive_account.vision_training.endpoint
    key          = azurerm_cognitive_account.vision_training.primary_access_key
    principal_id = azurerm_cognitive_account.vision_training.identity[0].principal_id
    id           = azurerm_cognitive_account.vision_training.id
  }
  sensitive = true
}
