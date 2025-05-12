# This module manages Key Vault role assignments
variable "key_vault_id" {
  description = "ID of the Key Vault to manage role assignments"
  type        = string
}

variable "role_assignments" {
  description = "List of role assignments to create"
  type = list(object({
    principal_id                           = string
    name                                   = string
    role_definition_name                   = string # e.g., "Key Vault Administrator", "Key Vault Secrets User"
    condition                              = optional(string)
    condition_version                      = optional(string)
    delegated_managed_identity_resource_id = optional(string)
    description                            = optional(string)
    skip_service_principal_aad_check       = optional(bool)
  }))
  default = []
}

variable "managed_identities" {
  description = "List of managed identities that need access to Key Vault secrets (shorthand for common case)"
  type = list(object({
    principal_id = string
    name         = string
  }))
  default = []
}

# Create role assignments from the detailed list
resource "azurerm_role_assignment" "role_assignments" {
  for_each = { for idx, assignment in var.role_assignments : "${assignment.name}-${assignment.role_definition_name}" => assignment }

  scope                = var.key_vault_id
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id

  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  description                            = each.value.description
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}

# Grant Key Vault Secrets User role to managed identities (simplified case)
resource "azurerm_role_assignment" "managed_identity_access" {
  for_each = { for idx, identity in var.managed_identities : identity.name => identity }

  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value.principal_id
}

output "outputs" {
  description = "All outputs from the Key Vault RBAC module"
  value = {
    role_assignments = merge(
      { for name, assignment in azurerm_role_assignment.role_assignments : name => assignment.id },
      { for name, assignment in azurerm_role_assignment.managed_identity_access : name => assignment.id }
    )
    role_assignment_principals = merge(
      { for name, assignment in azurerm_role_assignment.role_assignments : name => assignment.principal_id },
      { for name, assignment in azurerm_role_assignment.managed_identity_access : name => assignment.principal_id }
    )
  }
}
