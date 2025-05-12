# Environment variables for the frontend application
output "frontend_environment_variables" {
  description = "Environment variables for the frontend Streamlit application"
  value = {
    # Storage configuration
    STORAGE_ACCOUNT_NAME      = module.storage.outputs.storage_account_name
    STORAGE_CONNECTION_STRING = module.storage.outputs.storage_account_connection_string
    CONTAINER_NAME            = "floorplans"

    # Function App configuration
    FUNCTION_APP_URL = module.function.outputs.function_app_url
  }
  sensitive = true
}

# Environment variables for the Azure Functions API
output "function_app_environment_variables" {
  description = "Environment variables for the Azure Functions application"
  value = {
    # Azure Functions configuration
    AzureWebJobsStorage      = module.function_storage.outputs.storage_account_connection_string
    FUNCTIONS_WORKER_RUNTIME = "python"

    # Vision API configuration
    VISION_ENDPOINT = module.vision.outputs.endpoint
    VISION_API_KEY  = module.vision.outputs.key

    # OpenAI configuration
    OPENAI_API_KEY      = module.openai.openai.key
    OPENAI_API_ENDPOINT = module.openai.openai.endpoint
    OPENAI_DEPLOYMENT   = "gpt-4"

    # Storage configuration for blob operations
    STORAGE_CONNECTION_STRING = module.storage.outputs.storage_account_connection_string

    # Application Insights
    APPLICATIONINSIGHTS_CONNECTION_STRING = module.appinsights.outputs.connection_string
  }
  sensitive = true
}

# Key resources for reference
output "resource_ids" {
  description = "Resource IDs for reference"
  value = {
    resource_group_id = azurerm_resource_group.rg.id
    key_vault_id      = module.keyvault.outputs.key_vault_id
    storage_id        = module.storage.outputs.id
    function_app_id   = module.function.outputs.function_app_id
    web_app_id        = module.webapp.outputs.web_app_id
  }
}

# Resource URLs and endpoints
output "resource_endpoints" {
  description = "Resource endpoints and URLs"
  value = {
    function_app_url = module.function.outputs.function_app_url
    web_app_url      = module.webapp.outputs.web_app_url
    key_vault_uri    = module.keyvault.outputs.key_vault_uri
    vision_endpoint  = module.vision.outputs.endpoint
    openai_endpoint  = module.openai.openai.endpoint
  }
}
