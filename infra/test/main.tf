terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_deleted_keys_on_destroy = false
      purge_soft_deleted_secrets_on_destroy = false
    }
  }
}

resource "azurerm_resource_group" "temp_rg" {
  name     = "vision-test-rg"
  location = "westus2"
}

variable "vision_prediction_sku_name" {
  type        = string
  description = "The SKU name for the Custom Vision Prediction service"
  default     = "F0"  # Free tier by default
}

variable "vision_training_sku_name" {
  type        = string
  description = "The SKU name for the Custom Vision Training service"
  default     = "F0"  # Free tier by default
}

# Vision Module - AI Services region
module "vision" {
  source              = "./modules/vision"
  resource_group_name = azurerm_resource_group.temp_rg.name
  location            = "westus2"
  resource_token      = "vision-test"
  sku_name            = "S1"
  prediction_sku_name = var.vision_prediction_sku_name
  training_sku_name   = var.vision_training_sku_name
}

output "vision_outputs" {
  value = module.vision.outputs
  sensitive = true
}

output "vision_prediction" {
  value = module.vision.prediction
  sensitive = true
}

output "vision_training" {
  value = module.vision.training
  sensitive = true
}
