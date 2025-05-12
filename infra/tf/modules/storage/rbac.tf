// This module-specific RBAC implementation allows direct assignment of roles
// when creating a storage account without needing to call the separate RBAC module
variable "role_assignments" {
  description = "List of role assignments to create on the storage account"
  type = list(object({
    role_definition_name = string
    principal_id         = string
  }))
  default = []
}

resource "azurerm_role_assignment" "storage_role_assignments" {
  count                = length(var.role_assignments)
  scope                = azurerm_storage_account.storage.id
  role_definition_name = var.role_assignments[count.index].role_definition_name
  principal_id         = var.role_assignments[count.index].principal_id
}
