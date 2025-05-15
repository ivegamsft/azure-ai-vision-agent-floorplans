# Testing Against Azure Deployed Resources

This document explains how to run the test suite against the deployed Azure Function App rather than local resources.

## Environment Setup

The test suite has been updated to use the deployed Azure resources by default. The main resources used are:

- **Function App**: `func-ulc72fwx-zd61.azurewebsites.net`
- **Web App**: `app-ulc72fwx-zd61.azurewebsites.net`
- **Storage Account**: `stulc72fwxzd61`
- **Container**: `floorplans`
- **Vision Services**: `cog-ulc72fwx-zd61-vision-vision`, `cog-ulc72fwx-zd61-vision-prediction`, `cog-ulc72fwx-zd61-vision-vision-training`

## Required Environment Variables

Before running the tests, you need to set the following environment variables:

```
# Azure resources
STORAGE_ACCOUNT_NAME=stulc72fwxzd61
CONTAINER_NAME=floorplans
FUNCTION_APP_URL=https://func-ulc72fwx-zd61.azurewebsites.net

# Custom Vision settings
CV_ENDPOINT=https://cog-ulc72fwx-zd61-vision-vision.cognitiveservices.azure.com/
CV_PROJECT_ID=your-project-id
CV_MODEL_NAME=your-model-name
CV_KEY=your-vision-api-key

# OpenAI settings
OPENAI_ENDPOINT=your-openai-endpoint
OPENAI_MODEL=your-deployment-name
OPENAI_API_VERSION=2024-02-01
```

## Authentication

The tests use Azure identity authentication. You need to be logged in with Azure CLI or have the appropriate Azure credentials configured:

```bash
az login
```

Alternatively, you can set environment variables for service principal authentication:

```
AZURE_TENANT_ID=your-tenant-id
AZURE_CLIENT_ID=your-client-id
AZURE_CLIENT_SECRET=your-client-secret
```

## Running the Tests

To run the tests against the deployed Azure resources:

```bash
pytest -xvs tests/test_function.py
```

## Test Configuration

The test configuration is managed in `tests/test_config.py`. This file configures the necessary environment variables for the tests to connect to Azure resources.

## Local Testing

To run tests against the local development environment instead, you can modify the test fixtures in `conftest.py` to use the `use_local_test_env` fixture instead of `use_azure_functions_test_env`.
