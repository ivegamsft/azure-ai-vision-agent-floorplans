variable "location" {
  type        = string
  description = "The Azure region where resources will be created"
}

variable "environment" {
  type        = string
  description = "Environment name"
  default     = "dev"
}

variable "python_version" {
  description = "Python version for Function App and Web App"
  type        = string
  default     = "3.9"
}

variable "vision_sku_name" {
  type        = string
  description = "The SKU name for the Computer Vision resource"
  default     = "S1"
}

variable "key_vault_admins" {
  type        = list(string)
  description = "List of service principal object IDs that should be Key Vault administrators"
  default     = []
}

variable "openai_sku_name" {
  type        = string
  description = "The SKU name for the OpenAI resource"
  default     = "S0"
}