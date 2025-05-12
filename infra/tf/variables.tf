variable "location" {
  type        = string
  description = "The Azure region where compute resources will be created"
  validation {
    condition = contains([
      "westus", "westus2", "westus3", "eastus", "eastus2",
      "northeurope", "westeurope", "francecentral"
    ], lower(var.location))
    error_message = "The location must be a valid Azure region that supports App Services and Functions."
  }
}

variable "ai_services_location" {
  type        = string
  description = "The Azure region where AI services (OpenAI) will be created"
  default     = "swedencentral"
  validation {
    condition = contains([
      "swedencentral", "westus", "japaneast", "switzerlandnorth"
    ], lower(var.ai_services_location))
    error_message = "The AI services location must be one of: Sweden Central, West US, Japan East, or Switzerland North as these regions support GPT-4V."
  }
}


variable "vision_ai_services_location" {
  type        = string
  description = "The Azure region where Custom Vision AI services will be created"
  default     = "westus2" // Or any other default you prefer
  validation {
    condition = contains([
      "westus", "westus2", "eastus", "westeurope" 
      // Add other valid regions for vision services if needed
    ], lower(var.vision_ai_services_location))
    error_message = "The Vision AI services location must be a valid region for Azure Vision services."
  }
}


variable "environment" {
  type        = string
  description = "Environment name"
  default     = "dev"
}

variable "python_version" {
  description = "Python version for Function App and Web App"
  type        = string
  default     = "3.10"
}

variable "vision_sku_name" {
  type        = string
  description = "The SKU name for the Computer Vision resource"
  default     = "S1"
}

variable "key_vault_admins" {
  type        = list(string)
  description = "List of Azure AD Object IDs that should have Key Vault Administrator role"
  default     = []
}

variable "openai_sku_name" {
  type        = string
  description = "The SKU name for the OpenAI resource"
  default     = "S0"
}
