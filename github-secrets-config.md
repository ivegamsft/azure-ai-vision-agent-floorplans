# GitHub Secrets and Variables for Floorplans Vision Agent

## GitHub Repository Secrets

These secrets should be set at the repository level:

| Secret Name | Value | Purpose |
|-------------|-------|---------|
| `AZURE_CLIENT_ID` | a534ef91-4ebd-494e-b28f-eeb9207f89f8 | Service principal client ID for GitHub Actions |
| `AZURE_TENANT_ID` | 62837751-4e48-4d06-8bcb-57be1a669b78 | Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | 844eabcc-dc96-453b-8d45-bef3d566f3f8 | Azure subscription ID |

## GitHub Repository Variables

These variables should be set at the repository level:

| Variable Name | Value | Purpose |
|--------------|-------|---------|
| `AZURE_FUNCTION_APP_NAME` | func-ulc72fwx-zd61 | Name of the Azure Function App |
| `AZURE_RESOURCE_GROUP` | rg-ulc72fwx-zd61-compute | Resource group for compute resources |
| `AZURE_WEBAPP_NAME` | app-ulc72fwx-zd61 | Name of the Azure Web App |

## Application Configuration Settings

These settings are already configured in the Azure resources but documented here for reference:

### Function App Settings
The Function App (func-ulc72fwx-zd61) has these key settings:
- `FUNCTIONS_WORKER_RUNTIME`: python
- `PYTHON_ISOLATE_WORKER_DEPENDENCIES`: 1
- `SCM_DO_BUILD_DURING_DEPLOYMENT`: true
- `OPENAI_API_VERSION`: 2024-02-01

### Web App Settings
The Web App (app-ulc72fwx-zd61) has these key settings:
- `CONTAINER_NAME`: floorplans
- `FUNCTION_START_URL`: https://func-ulc72fwx-zd61.azurewebsites.net/api/orchestrators/vision_agent_orchestrator
- `STORAGE_CONN_STR`: (Reference to Key Vault)
- `VISION_ENDPOINT`: (Reference to Key Vault)
- `VISION_KEY`: (Reference to Key Vault)
- `WEBSITES_PORT`: 8501

### Key Vault Secrets
The Key Vault (kv-ulc72fwx-zd61) contains these secrets:
- `appinsights-connection-string`
- `openai-endpoint`
- `openai-key`
- `storage-connection-string`
- `vision-endpoint`
- `vision-key`

## Resource Information

### Primary Resources
- **Key Vault**: kv-ulc72fwx-zd61 (https://kv-ulc72fwx-zd61.vault.azure.net/)
- **Function App**: func-ulc72fwx-zd61 (func-ulc72fwx-zd61.azurewebsites.net)
- **Web App**: app-ulc72fwx-zd61 (app-ulc72fwx-zd61.azurewebsites.net)
- **Storage Account**: stulc72fwxzd61
- **Vision Cognitive Account**: cog-ulc72fwx-zd61-vision-vision
- **Vision Prediction Account**: cog-ulc72fwx-zd61-vision-prediction
- **Vision Training Account**: cog-ulc72fwx-zd61-vision-vision-training

### Service Principal for GitHub Actions
- **Name**: github-actions-floorplans
- **Client ID**: a534ef91-4ebd-494e-b28f-eeb9207f89f8
- **Has Contributor access to**:
  - Resource Group: rg-ulc72fwx-zd61-compute
  - Resource Group: rg-ulc72fwx-zd61-ai
