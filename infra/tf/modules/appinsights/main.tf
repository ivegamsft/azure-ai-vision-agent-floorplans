variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_token" {
  description = "The token to use for App Insights naming from the naming module"
  type        = string
}

variable "log_analytics_token" {
  description = "The token to use for Log Analytics workspace naming from the naming module"
  type        = string
}

resource "azurerm_log_analytics_workspace" "workspace" {
  name                = var.log_analytics_token
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "appinsights" {
  name                = var.resource_token
  resource_group_name = var.resource_group_name
  location            = var.location
  workspace_id        = azurerm_log_analytics_workspace.workspace.id
  application_type    = "web"
  retention_in_days   = 90

  daily_data_cap_in_gb = 1
  daily_data_cap_notifications_disabled = false

  tags = {
    "app-type" = "durable-functions"
  }
}

resource "azurerm_application_insights_analytics_item" "durable_functions" {
  name                    = "durable-functions-analytics"
  application_insights_id = azurerm_application_insights.appinsights.id
  content                = <<EOF
requests
| where operation_Name startswith "DurableTask"
| extend executionId = tostring(customDimensions["prop__executionId"])
| extend instanceId = tostring(customDimensions["prop__instanceId"])
| extend taskHub = tostring(customDimensions["prop__taskHub"])
| extend durableOperationType = tostring(customDimensions["Category"])
| order by timestamp desc
EOF
  scope                  = "shared"
  type                   = "query"
}

output "outputs" {
  description = "All outputs from the App Insights module"
  value = {
    instrumentation_key = azurerm_application_insights.appinsights.instrumentation_key
    connection_string   = azurerm_application_insights.appinsights.connection_string
    workspace_id        = azurerm_log_analytics_workspace.workspace.id
  }
  sensitive = true
}
