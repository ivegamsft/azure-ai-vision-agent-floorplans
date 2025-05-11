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

variable "sku_name" {
  description = "The Name of the SKU used for this Key Vault. Default: standard"
  type        = string
  default     = "standard"
}

variable "enabled_for_deployment" {
  description = "Whether Azure Virtual Machines are permitted to retrieve certificates stored as secrets from this key vault"
  type        = bool
  default     = false
}

variable "enabled_for_disk_encryption" {
  description = "Whether Azure Disk Encryption is permitted to retrieve secrets from the key vault"
  type        = bool
  default     = false
}

variable "enabled_for_template_deployment" {
  description = "Whether Azure Resource Manager is permitted to retrieve secrets from this key vault"
  type        = bool
  default     = false
}

variable "enable_rbac_authorization" {
  description = "Whether RBAC authorization should be used for data actions instead of Access Policies"
  type        = bool
  default     = true
}

variable "purge_protection_enabled" {
  description = "Whether to enable purge protection"
  type        = bool
  default     = false
}

variable "soft_delete_retention_days" {
  description = "Number of days after which soft-deleted key vaults are purged"
  type        = number
  default     = 90
}

variable "network_acls" {
  description = "Network rules to apply to key vault"
  type = object({
    bypass                     = string
    default_action             = string
    ip_rules                   = list(string)
    virtual_network_subnet_ids = list(string)
  })
  default = {
    bypass                     = "AzureServices"
    default_action             = "Allow"
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }
}

variable "tags" {
  description = "Tags to apply to the key vault"
  type        = map(string)
  default     = {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                            = var.resource_token
  location                        = var.location
  resource_group_name             = var.resource_group_name
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  sku_name                        = var.sku_name
  enabled_for_deployment          = var.enabled_for_deployment
  enabled_for_disk_encryption     = var.enabled_for_disk_encryption
  enabled_for_template_deployment = var.enabled_for_template_deployment
  enable_rbac_authorization       = var.enable_rbac_authorization
  purge_protection_enabled        = var.purge_protection_enabled
  soft_delete_retention_days      = var.soft_delete_retention_days
  tags                            = var.tags

  network_acls {
    bypass                     = var.network_acls.bypass
    default_action             = var.network_acls.default_action
    ip_rules                   = var.network_acls.ip_rules
    virtual_network_subnet_ids = var.network_acls.virtual_network_subnet_ids
  }

  lifecycle {
    create_before_destroy = false
  }
}

# Add current user as Key Vault Administrator
resource "azurerm_role_assignment" "current_user_admin" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
  description          = "Current user admin access"
}

output "key_vault_id" {
  value = azurerm_key_vault.kv.id
}

output "key_vault_name" {
  value = azurerm_key_vault.kv.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.kv.vault_uri
}

output "current_user_object_id" {
  value = data.azurerm_client_config.current.object_id
}

output "admin_role_assignment_id" {
  value = azurerm_role_assignment.current_user_admin.id
}
