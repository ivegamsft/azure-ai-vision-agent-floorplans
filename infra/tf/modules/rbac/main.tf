# This module manages Azure RBAC role assignments
resource "azurerm_role_assignment" "role_assignment" {
  scope                = var.scope
  role_definition_name = var.role_definition_name
  principal_id         = var.principal_id
}

variable "scope" {
  type        = string
  description = "The scope at which the role assignment applies to, such as resource IDs"
}

variable "role_definition_name" {
  type        = string
  description = "The name of the Role Definition to assign to the principal"
}

variable "principal_id" {
  type        = string
  description = "The ID of the Principal to assign the Role Definition to"
}

output "outputs" {
  description = "The Role Assignment ID"
  value = {
    role_assignment_id = azurerm_role_assignment.role_assignment.id
  }
}
