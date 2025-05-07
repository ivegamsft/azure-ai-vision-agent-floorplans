variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_token" {
  description = "The token to use for Key Vault naming from the naming module"
  type        = string
}

variable "secrets" {
  description = "Map of secrets to store in Key Vault"
  type = map(object({
    value        = string
    content_type = optional(string)
  }))
  sensitive = false # Changed from true to false since we handle sensitivity at the secret level
}

variable "managed_identities" {
  description = "List of managed identities that need access to Key Vault secrets"
  type = list(object({
    principal_id = string
    name         = string
  }))
  default = []
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                       = var.resource_token
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  purge_protection_enabled   = false
  soft_delete_retention_days = 90

  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow"
  }
}

resource "azurerm_key_vault_secret" "secrets" {
  for_each = nonsensitive(var.secrets) # Use nonsensitive() to allow for_each while still protecting values

  name         = each.key
  value        = each.value.value
  content_type = each.value.content_type
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azurerm_key_vault.kv]
}

# Grant Key Vault Secrets User role to managed identities
resource "azurerm_role_assignment" "managed_identity_access" {
  for_each = { for idx, identity in var.managed_identities : identity.name => identity }

  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value.principal_id
}

output "outputs" {
  description = "All outputs from the Key Vault module"
  value = {
    key_vault_id  = azurerm_key_vault.kv.id
    key_vault_uri = azurerm_key_vault.kv.vault_uri
  }
}
