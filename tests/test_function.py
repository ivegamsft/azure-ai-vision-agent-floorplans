# filepath: f:\Git\azure-ai-vision-agent-floorplans\tests\test_function.py
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
from function_app import myApp, read_image, object_detection, summarize_results, http_start

class MockDurableOrchestrationClient:
    def __init__(self, context):
        self._task_hub_name = "TestHub"
        self._create_new_orchestration_url = ""
        self._create_status_query_url = ""
        
    async def start_new(self, orchestration_function_name, client_input=None):
        return "test-instance-id"

    def create_check_status_response(self, request, instance_id):
        return func.HttpResponse(
            body=json.dumps({
                "id": "test-instance-id",
                "statusQueryGetUri": "https://test-status-url"
            }),
            status_code=202,
            headers={"Content-Type": "application/json"}
        )

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

    # Create the binding info that will be passed to http_start
    mock_binding = {
        "taskHubName": "TestHub",
        "creationUrls": {"createNewInstance": "http://test"},
        "managementUrls": {"statusQueryGetUri": "http://test"},
        "connection": "Storage"
    }

    # Create a mock durable client that returns JSON
    with patch('function_app.credential'), \
         patch('azure.durable_functions.DurableOrchestrationClient', MockDurableOrchestrationClient):
        result = await http_start(req=mock_req, client=json.dumps(mock_binding))
        
        assert result.status_code == 202
        response_body = json.loads(result.get_body().decode('utf-8'))
        assert response_body['id'] == 'test-instance-id'
        assert 'statusQueryGetUri' in response_body

class MockBlobClient:
    def __init__(self, container_name, blob_name, credential=None, download_content=None):
        self.container_name = container_name
        self.blob_name = blob_name
        self.credential = credential
        self.download_content = download_content
        
    def download_blob(self):
        if callable(self.download_content):
            return self.download_content()
        return self.download_content
        
    @classmethod
    def from_connection_string(cls, conn_str, container_name, blob_name):
        return cls(container_name=container_name, blob_name=blob_name)

class MockBlobContentResponse:
    def __init__(self, content):
        self.content = content
        
    def readall(self):
        return self.content

def test_read_image(use_azure_functions_test_env):
    """Test image reading from blob storage"""
    # Create test image data
    test_image = Image.new('RGB', (100, 100), color='red')
    img_io = io.BytesIO()
    test_image.save(img_io, format='PNG')
    img_bytes = img_io.getvalue()

    # Create a mock download response
    download_content = MockBlobContentResponse(img_bytes)
    
    # Create a mock blob client factory
    def create_mock_blob_client(*args, **kwargs):
        return MockBlobClient(
            container_name=kwargs.get('container_name', 'test-container'), 
            blob_name=kwargs.get('blob_name', 'test.png'),
            download_content=download_content
        )

    # Patch environment and dependencies
    with patch.dict(os.environ, {
            'AzureWebJobsStorage': 'DefaultEndpointsProtocol=https;AccountName=test;AccountKey=test;EndpointSuffix=core.windows.net'
        }), \
         patch('azure.storage.blob.BlobClient', side_effect=create_mock_blob_client):
        
        result = read_image(json.dumps({
            "container": "test-container",
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

class MockResponse:
    def __init__(self, predictions):
        self.predictions = predictions

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

class MockCustomVisionPredictionClient:
    def __init__(self, endpoint, credentials):
        self.endpoint = endpoint
        self.credentials = credentials
    
    def detect_image(self, project_id, iteration_name, image_data):
        bbox = MockBBox(0.1, 0.1, 0.2, 0.2)
        pred = MockPrediction("door", 0.95, bbox)
        return MockResponse([pred])

def test_object_detection(use_azure_functions_test_env):
    """Test Custom Vision object detection"""
    # Create test image data
    test_image = Image.new('RGB', (100, 100), color='red')
    img_io = io.BytesIO()
    test_image.save(img_io, format='PNG')
    img_base64 = base64.b64encode(img_io.getvalue()).decode('utf-8')

    with patch('function_app.CustomVisionPredictionClient', MockCustomVisionPredictionClient), \
         patch.dict(os.environ, {
            'CV_ENDPOINT': 'https://test-endpoint',
            'CV_KEY': 'test-key',
            'CV_PROJECT_ID': 'test-project',
            'CV_MODEL_NAME': 'test-model'
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

@patch('openai.AzureOpenAI')
def test_summarize_results(mock_openai_class, use_azure_functions_test_env):
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
    mock_openai_class.return_value = mock_client

    with patch.dict(os.environ, {
            'OPENAI_ENDPOINT': 'https://test-endpoint',
            'OPENAI_KEY': 'test-key',
            'OPENAI_MODEL': 'test-model'
         }):
        # Test summarize_results function
        result = summarize_results(json.dumps(test_payload))
        
        # Verify the result
        assert result == "Test summary"
        
        # Verify the OpenAI client was created with correct parameters
        mock_openai_class.assert_called_once_with(
            azure_endpoint=os.environ['OPENAI_ENDPOINT'],
            api_key=os.environ['OPENAI_KEY'],
            api_version="2023-07-01-preview"
        )
