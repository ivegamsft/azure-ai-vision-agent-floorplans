# This module manages the Azure OpenAI Model Deployment for AI Foundry project

variable "project_token" {
  description = "The token to use for Azure OpenAI deployment naming"
  type        = string
}

variable "openai_account_id" {
  description = "The ID of the Azure OpenAI account"
  type        = string
}

variable "model_name" {
  description = "The name of the OpenAI model to deploy"
  type        = string
  default     = "gpt-4"
}

variable "model_version" {
  description = "The version of the OpenAI model to deploy"
  type        = string
  default     = "turbo-2024-04-09"
}

variable "model_format" {
  description = "The format of the OpenAI model"
  type        = string
  default     = "OpenAI"
}

resource "azurerm_cognitive_deployment" "project" {
  name                 = var.project_token
  cognitive_account_id = var.openai_account_id

  model {
    format  = var.model_format
    name    = var.model_name
    version = var.model_version
  }

  sku {
    name     = "Standard"
    capacity = 1
  }

  rai_policy_name = "Microsoft.Default"
}

output "outputs" {
  description = "All outputs from the Azure OpenAI deployment"
  value = {
    id = azurerm_cognitive_deployment.project.id
  }
  sensitive = true
}
