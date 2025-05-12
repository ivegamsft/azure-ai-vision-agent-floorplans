# Module-specific role assignments variable allows direct assignment of roles 
# to webapp identity when creating the web app, providing a convenient way to 
# set up permissions without multiple module calls
variable "role_assignments" {
  description = "List of role assignments to create for the web app identity"
  type = list(object({
    scope                = string
    role_definition_name = string
  }))
  default = []
}

# Create a user assigned managed identity for the web app
resource "azurerm_user_assigned_identity" "webapp_identity" {
  name                = "${var.resource_token}-identity"
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_role_assignment" "webapp_role_assignments" {
  count                = length(var.role_assignments)
  scope                = var.role_assignments[count.index].scope
  role_definition_name = var.role_assignments[count.index].role_definition_name
  principal_id         = azurerm_user_assigned_identity.webapp_identity.principal_id
}

output "identity" {
  description = "The user assigned managed identity created for the web app"
  value = {
    id           = azurerm_user_assigned_identity.webapp_identity.id
    principal_id = azurerm_user_assigned_identity.webapp_identity.principal_id
    client_id    = azurerm_user_assigned_identity.webapp_identity.client_id
  }
}
