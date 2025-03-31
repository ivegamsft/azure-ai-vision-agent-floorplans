# Azure Durable Function App for Floor Plan Analysis

This repository contains an Azure Durable Function App designed to analyze floor plans using an object detection model from Azure Custom Vision. The app further leverages Azure OpenAI to analyze the detected objects and compare them to a reference image for deeper insights.

## Features

- **Object Detection**: Uses Azure Custom Vision to detect objects in floor plans.
- **AI-Powered Analysis**: Employs Azure OpenAI to analyze detected objects and compare them to a reference image.
- **Durable Functions**: Implements Azure Durable Functions to orchestrate the workflow, ensuring scalability and reliability.
- **Streamlit Frontend**: Frontend to upload images and trigger the Azure Durable Function

## Prerequisites

Before running the application, ensure you have the following:

1. An active Azure subscription.
2. Azure resources:
   - Azure Custom Vision project with a trained object detection model.
   - Azure OpenAI resource with a gpt-4o deployment
   - Azure Storage account and container
3. Python 3.8+ installed locally.
4. Azure CLI installed and authenticated.
VSCode is recommended to run this project

## Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/vhoudebine/azureai-vision-agent-floorplans.git
   cd azureai-vision-agent-floorplans
   ```

2. Create a `.env` file in the root directory with the following content:
   ```env
   STORAGE_CONN_STR="your-storage-connection-string"
   CONTAINER_NAME="your-container-name"
   ```

   Create a `local.settings.json` file, this will set the environment variables for the Function App

   ```json
   {
      "IsEncrypted": false,
      "Values": {
         "AzureWebJobsStorage": "your-storage-account-connection-string",
         "FUNCTIONS_WORKER_RUNTIME": "python",
         "StorageConnectionString": "your-storage-account-connection-string",
         "BLOB_CONNECTION_STRING": "your-storage-account-connection-string",
         "CV_ENDPOINT": "https://your-endpoint.cognitiveservices.azure.com",
         "CV_KEY": "your-custom-vision-key",
         "CV_PROJECT_ID": "your-custom-vision-project-id",
         "CV_MODEL_NAME": "your-custom-vision-model-name",
         "OPENAI_ENDPOINT": "https://your-endpoint.openai.azure.com/",
         "OPENAI_KEY": "your-azure-openai-api-key",
         "OPENAI_MODEL": "your-gpt-4o-model-deployment-name"
      }
   }
   ```

3. Install the required Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Run the Azure Function app locally (tutorial [here](https://learn.microsoft.com/en-us/azure/azure-functions/durable/quickstart-python-vscode))
5. Deploy to Azure and modify the Azure Function App URL in the .env file. Make sure the Azure Function App has the right environment variables set-up. See how to publish application setting [here](https://learn.microsoft.com/en-us/azure/azure-functions/functions-develop-vs-code?tabs=node-v4%2Cpython-v2%2Cisolated-process%2Cquick-create&pivots=programming-language-python#publish-application-settings)
6. Run the frontend
```
streamlit run ./frontend/app.py
```



## Notes

- Ensure sensitive information such as API keys and connection strings are stored securely and not shared publicly.
- For more details on Azure Functions and Durable Functions, refer to the [official documentation](https://learn.microsoft.com/en-us/azure/azure-functions/).

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.