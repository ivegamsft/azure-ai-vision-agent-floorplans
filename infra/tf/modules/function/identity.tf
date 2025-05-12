# Create a user assigned managed identity for the function app
resource "azurerm_user_assigned_identity" "function_identity" {
  name                = "${var.resource_token}-identity"
  resource_group_name = var.resource_group_name
  location            = var.location
}

variable "role_assignments" {
  description = "List of role assignments to create for the function identity"
  type = list(object({
    scope                = string
    role_definition_name = string
  }))
  default = []
}

resource "azurerm_role_assignment" "function_role_assignments" {
  count                = length(var.role_assignments)
  scope                = var.role_assignments[count.index].scope
  role_definition_name = var.role_assignments[count.index].role_definition_name
  principal_id         = azurerm_user_assigned_identity.function_identity.principal_id
}

output "identity" {
  description = "The user assigned managed identity created for the function app"
  value = {
    id           = azurerm_user_assigned_identity.function_identity.id
    principal_id = azurerm_user_assigned_identity.function_identity.principal_id
    client_id    = azurerm_user_assigned_identity.function_identity.client_id
  }
}
