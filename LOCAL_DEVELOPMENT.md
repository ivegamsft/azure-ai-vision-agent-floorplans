# Local Development Setup

## Component Isolation

This project uses separate Python virtual environments for the API and frontend components to match the production environment where they run in separate App Services.

### API (Azure Functions)
```powershell
# Create and activate API virtual environment
cd api
python -m venv .venv
.venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Start the function host
func host start
```

The API will run at http://localhost:7071

### Frontend (Streamlit)
```powershell
# In a separate terminal
# Create and activate frontend virtual environment
cd frontend
python -m venv .venv
.venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Start Streamlit
streamlit run app.py
```

The frontend will run at http://localhost:8501

## Environment Configuration

### API (local.settings.json)
```json
{
  "Values": {
    "AzureWebJobsStorage": "<storage-connection-string>",
    "FUNCTIONS_WORKER_RUNTIME": "python",
    "OPENAI_ENDPOINT": "<openai-endpoint>",
    "OPENAI_KEY": "<openai-key>",
    "OPENAI_MODEL": "gpt-4",
    "STORAGE_ACCOUNT_NAME": "<storage-account-name>",
    "CV_KEY": "<custom-vision-key>",
    "VISION_PREDICTION_ENDPOINT": "<vision-endpoint>",
    "CV_PROJECT_ID": "<project-id>",
    "CV_MODEL_NAME": "<model-name>"
  }
}
```

### Frontend (.env)
```properties
# Function App settings - default to local development
FUNCTION_APP_URL="http://localhost:7071"

# Storage settings
STORAGE_ACCOUNT_NAME="<storage-account-name>"
STORAGE_CONNECTION_STRING="<storage-connection-string>"
CONTAINER_NAME="floorplans"
```

## Development Workflow

1. Start the API:
   ```powershell
   cd api
   .venv\Scripts\activate
   func host start
   ```

2. In a separate terminal, start the frontend:
   ```powershell
   cd frontend
   .venv\Scripts\activate
   streamlit run app.py
   ```

3. The frontend will automatically connect to the local API endpoint

## Important Notes

- Each component (API and frontend) has its own virtual environment to maintain isolation
- The frontend defaults to connecting to the local API (http://localhost:7071)
- Both components can share the same Azure Storage account
- For production, the frontend's FUNCTION_APP_URL would be updated to point to the deployed Azure Function
- Python requirements:
  - API: Python 3.9 (Azure Functions requirement)
  - Frontend: Python 3.9+ (compatible with all Python versions)
