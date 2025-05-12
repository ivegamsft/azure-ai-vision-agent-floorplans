# This module manages Key Vault secrets
variable "key_vault_id" {
  type        = string
  description = "ID of the Key Vault to store secrets"
}

variable "secrets" {
  type = map(object({
    value        = string
    content_type = optional(string)
    tags         = optional(map(string))
  }))
  description = "Map of secrets to create in the Key Vault. The key is the secret name."
  sensitive   = false # We handle the sensitivity at the individual value level
}

variable "secret_expiry_date" {
  type        = string
  description = "Expiration UTC datetime for all secrets (optional)"
  default     = null
}

variable "secret_not_before_date" {
  type        = string
  description = "Not before UTC datetime for all secrets (optional)"
  default     = null
}

variable "dependent_role_assignment_id" {
  description = "ID of the role assignment to depend on for RBAC propagation"
  type        = string
}

# Add a time delay after role assignments
resource "time_sleep" "wait_for_rbac" {
  create_duration = "60s"

  triggers = {
    key_vault_id = var.key_vault_id
  }
}

resource "azurerm_key_vault_secret" "secrets" {
  for_each = var.secrets

  name         = each.key
  value        = each.value.value
  key_vault_id = var.key_vault_id

  content_type    = each.value.content_type
  expiration_date = var.secret_expiry_date
  not_before_date = var.secret_not_before_date
  tags            = each.value.tags

  depends_on = [
    time_sleep.wait_for_rbac
  ]

  lifecycle {
    ignore_changes = [
      value # Don't update secret if it changes externally
    ]
  }
}

output "outputs" {
  description = "All outputs from the Key Vault Secrets module"
  value = {
    secret_uris     = { for name, secret in azurerm_key_vault_secret.secrets : name => secret.id }
    secret_versions = { for name, secret in azurerm_key_vault_secret.secrets : name => secret.version }
  }
}
