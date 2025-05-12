# Azure AI Vision Agent Scripts

This directory contains configuration scripts and sensitive information needed for setting up and maintaining the Azure AI Vision Agent for Floorplans.

## Scripts

### `set-github-secrets.ps1`

This script uses the GitHub CLI to set up all the required GitHub repository secrets and variables for CI/CD workflows. It includes:

- Setting repository secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
- Setting repository variables: `AZURE_FUNCTION_APP_NAME`, `AZURE_RESOURCE_GROUP`, `AZURE_WEBAPP_NAME`

#### Usage

```powershell
# From the scripts directory
.\set-github-secrets.ps1

# From the repository root
.\scripts\set-github-secrets.ps1
```

Requirements:
- GitHub CLI (`gh`) must be installed and authenticated
- You must have admin access to the GitHub repository

## Sensitive Information

The `service-principal-credentials.md` file contains sensitive information about the service principal used for GitHub Actions. This file is excluded from git tracking via `.gitignore` to prevent accidental exposure of secrets.

Note: Store the information from this file in a secure location (like a password manager) and consider deleting the file once the information is securely stored.
