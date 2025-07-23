# Azure AI Vision Agent Scripts

This directory contains configuration scripts and testing utilities needed for setting up and maintaining the Azure AI Vision Agent for Floorplans.

## Scripts

### `test-dependencies.sh`

A script to validate that all project dependencies can be installed locally. This script mirrors the dependency installation steps used in the GitHub Actions workflows.

#### Usage

```bash
# From the project root directory
./scripts/test-dependencies.sh
```

#### Requirements

- Python 3.10 (preferred) or compatible Python version
- pip package manager
- Internet connection for downloading packages

#### What it does

1. Creates a temporary virtual environment
2. Installs API dependencies from `api/requirements.txt`
3. Validates that key API modules can be imported
4. Installs frontend dependencies from `frontend/requirements.txt`
5. Validates that key frontend modules can be imported
6. Cleans up the temporary environment

This script is useful for:
- Testing dependency installation locally before pushing changes
- Troubleshooting GitHub Actions workflow failures
- Validating that requirements.txt files are complete and correct

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
