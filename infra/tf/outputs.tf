# Combined deployment information output
output "deployment_info" {
  description = "Complete deployment information including all environment variables, resource IDs, and endpoints"
  value = {
    environment_variables = {
      frontend = {
        # Storage configuration
        STORAGE_ACCOUNT_NAME      = module.storage.outputs.storage_account_name
        STORAGE_CONNECTION_STRING = module.storage.outputs.storage_account_connection_string
        CONTAINER_NAME            = "floorplans" //TODO: This should come from outputs
        # Function App configuration
        FUNCTION_APP_URL = module.function.outputs.function_app_url
      }
      function_app = {
        # Azure Functions configuration
        AzureWebJobsStorage      = module.function_storage.outputs.storage_account_connection_string
        FUNCTIONS_WORKER_RUNTIME = "python" //TODO: This should come from outputs
        # Vision API configuration
        VISION_ENDPOINT = module.vision.outputs.endpoint
        VISION_API_KEY  = module.vision.outputs.key
        # OpenAI configuration
        OPENAI_API_KEY      = module.openai.openai.key
        OPENAI_API_ENDPOINT = module.openai.openai.endpoint
        OPENAI_DEPLOYMENT   = "gpt-4" //TODO: This should come from outputs
        # Storage configuration for blob operations
        STORAGE_CONNECTION_STRING = module.storage.outputs.storage_account_connection_string
        # Application Insights
        APPLICATIONINSIGHTS_CONNECTION_STRING = module.appinsights.outputs.connection_string
      }
    }
    resources = {
      ids = {
        resource_group = azurerm_resource_group.rg.id
        key_vault      = module.keyvault.outputs.key_vault_id
        storage        = module.storage.outputs.id
        function_app   = module.function.outputs.name
        web_app        = module.webapp.outputs.name
      }
      endpoints = {
        function_app = module.function.outputs.function_app_url
        web_app      = module.webapp.outputs.webapp_url
        key_vault    = module.keyvault.outputs.key_vault_uri
        vision       = module.vision.outputs.endpoint
        openai       = module.openai.openai.endpoint
      }
    }
  }
  sensitive = true
}
