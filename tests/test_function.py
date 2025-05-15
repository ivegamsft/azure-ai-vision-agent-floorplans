import pytest
import azure.functions as func
import azure.durable_functions as df
import json
import base64
from unittest.mock import MagicMock, patch, AsyncMock
import os
import sys
from PIL import Image
import io
import logging
from msrest.authentication import ApiKeyCredentials
from openai import AzureOpenAI

# Add the root directory to Python path
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from api.function_app import myApp, read_image, object_detection, summarize_results, http_start

class MockDurableOrchestrationClient:
    def __init__(self, client_config=None):
        self._task_hub_name = "TestHub"
        self._create_new_orchestration_url = ""
        self._create_status_query_url = ""
        self._client_config = client_config
        # Use the Azure Function URL for tests
        self._post_instance_url = "https://func-ulc72fwx-zd61.azurewebsites.net/api/orchestrators/vision_agent_orchestrator"
        
        try:
            if isinstance(client_config, str):
                client_config = json.loads(client_config)
            if client_config and client_config.get("creationUrls", {}).get("createNewInstance"):
                self._post_instance_url = client_config["creationUrls"]["createNewInstance"]
        except:
            pass

        if self._client_config:
            self._task_hub_name = self._client_config.get("taskHubName", "TestHub")
            self._create_new_orchestration_url = self._post_instance_url

    def get_client_input_endpoint(self):
        return self._post_instance_url
          async def start_new(self, orchestration_function_name, client_input=None):
        """Start a new orchestration instance"""
        if client_input is not None:
            instance_id = f"test-{orchestration_function_name}-{hash(str(client_input))}"
            await self._post_async_request(
                self._create_new_orchestration_url.format(name=orchestration_function_name), 
                client_input
            )
            return instance_id
        return "test-instance-id"

    async def _post_async_request(self, url, *args, **kwargs):
        """Simulate an HTTP POST request"""
        if not url:
            url = self._post_instance_url
        return {"id": "test-instance-id", "statusCode": 202, "purgeHistoryDeleteUri": "", "sendEventPostUri": ""}

    def create_check_status_response(self, request, instance_id):
        """Create a mock HTTP response for the orchestration status endpoint"""
        status_url = f"https://func-ulc72fwx-zd61.azurewebsites.net/runtime/webhooks/durabletask/instances/{instance_id}"
        return func.HttpResponse(
            body=json.dumps({
                "id": instance_id,
                "statusQueryGetUri": status_url,
                "sendEventPostUri": f"{status_url}/raiseEvent/{{eventName}}",
                "terminatePostUri": f"{status_url}/terminate",
                "purgeHistoryDeleteUri": f"{status_url}?purgeHistory=true"
            }),
            status_code=202,
            headers={"Content-Type": "application/json", "Location": status_url}
        )

class MockBlobContentResponse:
    def __init__(self, content):
        self.content = content
        
    def readall(self):
        return self.content

class MockBlobClient:
    def __init__(self, account_url=None, container_name=None, blob_name=None, credential=None, download_content=None):
        self.account_url = account_url
        self.container_name = container_name
        self.blob_name = blob_name
        self.credential = credential
        self.download_content = download_content
        
    def get_blob_client(self, container, blob):
        return MockBlobClient(
            account_url=self.account_url,
            container_name=container,
            blob_name=blob,
            credential=self.credential,
            download_content=self.download_content
        )
        
    def download_blob(self):
        if callable(self.download_content):
            return self.download_content()
        return self.download_content

@pytest.mark.asyncio
async def test_http_start(use_azure_functions_test_env):
    """Test HTTP-triggered function start"""
    # Create a mock request
    mock_req = MagicMock()
    mock_req.get_body.return_value = json.dumps({
        "container": "test-container",
        "filename": "test.png",
        "reference_filename": "reference.png",
        "analyze_prompt": "Test prompt"
    }).encode('utf-8')
    mock_req.route_params = {"functionName": "vision_agent_orchestrator"}
    mock_req.url = "https://func-ulc72fwx-zd61.azurewebsites.net/api/orchestrators/vision_agent_orchestrator"
    mock_req.function_directory = os.path.join(os.path.dirname(os.path.dirname(__file__)), "api")
    
    # Create the binding info that will be passed to http_start
    mock_binding = {
        "taskHubName": "TestHub",
        "creationUrls": {
            "createNewInstance": "https://func-ulc72fwx-zd61.azurewebsites.net/api/orchestrators/{name}"
        },
        "managementUrls": {"statusQueryGetUri": "https://func-ulc72fwx-zd61.azurewebsites.net/runtime/webhooks/durabletask/instances/{id}"},
        "connection": "Storage"
    }

    # Create a mock durable client that returns JSON
    with patch('api.function_app.credential'), \
         patch('azure.durable_functions.DurableOrchestrationClient', 
               side_effect=lambda x: MockDurableOrchestrationClient(mock_binding)):
        result = await http_start(req=mock_req, client=json.dumps(mock_binding))
        
        assert result.status_code == 202
        response_body = json.loads(result.get_body().decode('utf-8'))
        assert response_body['id'] == 'test-instance-id'
        assert 'statusQueryGetUri' in response_body

@patch('api.function_app.credential')
def test_read_image(mock_credential, use_azure_functions_test_env):
    """Test image reading from blob storage"""
    # Create test image data
    test_image = Image.new('RGB', (100, 100), color='red')
    img_io = io.BytesIO()
    test_image.save(img_io, format='PNG')
    img_bytes = img_io.getvalue()

    # Create a mock download response
    download_content = MockBlobContentResponse(img_bytes)
    
    # Set up the Azure AD token mock
    class MockToken:
        def __init__(self, token):
            self.token = token
        def get_token(self, *args, **kwargs):
            return self
    mock_token = MockToken("test-token")
    mock_credential.get_token.return_value = mock_token
    
    # Create a mock blob client factory
    def create_mock_blob_client(*args, **kwargs):
        account_url = f"https://{os.environ['STORAGE_ACCOUNT_NAME']}.blob.core.windows.net"
        client = MockBlobClient(
            account_url=account_url,
            credential=mock_credential,
            download_content=download_content
        )
        return client    # Patch environment and dependencies
    with patch.dict(os.environ, {
            'STORAGE_ACCOUNT_NAME': os.environ.get('STORAGE_ACCOUNT_NAME', 'stulc72fwxzd61'),
            'CONTAINER_NAME': os.environ.get('CONTAINER_NAME', 'floorplans')
        }), \
         patch('azure.storage.blob.BlobServiceClient', side_effect=create_mock_blob_client), \
         patch('azure.storage.blob.BlobClient', MockBlobClient):
        # Test read_image function
        result = read_image(json.dumps({
            "container": os.environ.get('CONTAINER_NAME', 'floorplans'),
            "filename": "test.png"
        }))
        
        # Verify result is base64 encoded image
        assert isinstance(result, str)
        decoded = base64.b64decode(result)
        assert len(decoded) > 0
        
        # Convert result back to image to verify integrity
        img = Image.open(io.BytesIO(decoded))
        assert img.size == (100, 100)
        assert img.mode == 'RGB'

def test_object_detection(use_azure_functions_test_env):
    """Test Custom Vision object detection"""
    # Create test image data
    test_image = Image.new('RGB', (100, 100), color='red')
    img_io = io.BytesIO()
    test_image.save(img_io, format='PNG')
    img_base64 = base64.b64encode(img_io.getvalue()).decode('utf-8')

    class MockBBox:
        def __init__(self, left, top, width, height):
            self.left = left
            self.top = top
            self.width = width
            self.height = height

    class MockPrediction:
        def __init__(self, tag_name, probability, bounding_box):
            self.tag_name = tag_name
            self.probability = probability
            self.bounding_box = bounding_box

    class MockResponse:
        def __init__(self, predictions):
            self.predictions = predictions

    class MockCustomVisionPredictionClient:
        def __init__(self, endpoint, credentials):
            self.endpoint = endpoint
            self.credentials = credentials
        
        def detect_image(self, project_id, iteration_name, image_data):
            bbox = MockBBox(0.1, 0.1, 0.2, 0.2)
            pred = MockPrediction("door", 0.95, bbox)
            return MockResponse([pred])    with patch('api.function_app.CustomVisionPredictionClient', MockCustomVisionPredictionClient), \
         patch.dict(os.environ, {
            'CV_ENDPOINT': os.environ.get('CV_ENDPOINT', 'https://cog-ulc72fwx-zd61-vision-vision.cognitiveservices.azure.com/'),
            'CV_KEY': os.environ.get('CV_KEY', 'test-key'),
            'CV_PROJECT_ID': os.environ.get('CV_PROJECT_ID', 'test-project'),
            'CV_MODEL_NAME': os.environ.get('CV_MODEL_NAME', 'test-model')
        }):
        # Test object_detection function
        result = object_detection(json.dumps({
            "image_data": img_base64
        }))
        
        # Verify the result
        assert isinstance(result, list)
        assert len(result) == 1
        prediction = json.loads(result[0])
        assert prediction["tag"] == "door"
        assert prediction["probability"] == 0.95

class MockAccessToken:
    def __init__(self, token):
        self.token = token
    def get_token(self, *args, **kwargs):
        return self

@patch('openai.AzureOpenAI')
@patch('api.function_app.credential')
def test_summarize_results(mock_openai_class, mock_credential, use_azure_functions_test_env):
    """Test OpenAI result summarization"""
    test_payload = {
        "object_results": [
            {
                "tag": "door",
                "probability": 0.95,
                "model_response": "DOOR"
            }
        ],
        "analyze_prompt": "Analyze this floorplan"
    }

    # Set up the Azure AD token mock
    mock_token = MockAccessToken("mock-token")
    mock_credential.get_token.return_value = mock_token
    
    # Create a mock completion response
    class MockChoice:
        def __init__(self):
            self.message = MagicMock(content="Test summary")
            
    class MockCompletion:
        def __init__(self):
            self.model = "test-model"
            self.choices = [MockChoice()]
            
    class MockChatCompletions:
        def create(self, *args, **kwargs):
            return MockCompletion()
            
    class MockChat:
        def __init__(self):
            self.completions = MockChatCompletions()

    # Set up the mock OpenAI client
    mock_client = MagicMock()
    mock_client.chat = MockChat()
    mock_openai_class.return_value = mock_client    with patch.dict(os.environ, {
            'OPENAI_ENDPOINT': os.environ.get('OPENAI_ENDPOINT', 'https://test-endpoint'),
            'OPENAI_MODEL': os.environ.get('OPENAI_MODEL', 'gpt-4o'),
            'OPENAI_API_VERSION': os.environ.get('OPENAI_API_VERSION', '2024-02-01')
         }):
        # Test summarize_results function
        result = summarize_results(json.dumps(test_payload))
        
        # Verify the result
        assert result == "Test summary"
        
        # Verify the OpenAI client was created with correct parameters
        mock_openai_class.assert_called_once_with(
            azure_endpoint=os.environ['OPENAI_ENDPOINT'],
            api_version=os.environ['OPENAI_API_VERSION'],
            azure_ad_token_provider=mock_credential
        )
