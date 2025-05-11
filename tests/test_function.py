import pytest
import azure.functions as func
import json
import base64
from unittest.mock import MagicMock, patch
import os
import sys
from PIL import Image
import io
import logging

# Import function app for testing
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from function_app import myApp

@pytest.mark.asyncio
async def test_http_start():
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

    # Create a mock durable client
    mock_client = MagicMock()
    mock_client.start_new = AsyncMock(return_value="test-instance-id")
    mock_client.create_check_status_response.return_value = func.HttpResponse(
        body=json.dumps({
            "id": "test-instance-id",
            "statusQueryGetUri": "https://test-status-url"
        }),
        status_code=202,
        headers={"Content-Type": "application/json"}
    )

    # Get the function from the durable app
    http_start_func = next(f for f in myApp._functions if f.name == "http_start")
    
    # Test http_start function
    result = await http_start_func.function(mock_req, client=mock_client)
    assert result.status_code == 202
    mock_client.start_new.assert_called_once()

def test_read_image():
    # Create test image data
    test_image = Image.new('RGB', (100, 100), color = 'red')
    img_io = io.BytesIO()
    test_image.save(img_io, format='PNG')
    img_bytes = img_io.getvalue()

    # Mock BlobServiceClient and its methods
    mock_blob_client = MagicMock()
    mock_blob_client.download_blob().readall.return_value = img_bytes

    mock_blob_service = MagicMock()
    mock_blob_service.get_blob_client.return_value = mock_blob_client

    with patch('azure.storage.blob.BlobServiceClient.from_connection_string') as mock_blob_service_client, \
         patch.dict(os.environ, {'BLOB_CONNECTION_STRING': 'test-conn-str'}):
        mock_blob_service_client.return_value = mock_blob_service
        
        # Test read_image function
        result = function_app.read_image(json.dumps({
            "container": "test-container",
            "filename": "test.png"
        }))
        
        # Verify result is base64 encoded image
        assert isinstance(result, str)
        decoded = base64.b64decode(result)
        assert len(decoded) > 0

def test_object_detection():
    # Create a test image
    test_image = Image.new('RGB', (100, 100), color = 'red')
    img_io = io.BytesIO()
    test_image.save(img_io, format='PNG')
    img_base64 = base64.b64encode(img_io.getvalue()).decode('utf-8')

    # Mock CustomVisionPredictionClient and its methods
    mock_prediction = MagicMock(
        tag_name="door",
        probability=0.95
    )
    mock_prediction.bounding_box.left = 0.1
    mock_prediction.bounding_box.top = 0.1
    mock_prediction.bounding_box.width = 0.2
    mock_prediction.bounding_box.height = 0.2

    mock_result = MagicMock()
    mock_result.predictions = [mock_prediction]

    # Mock the CustomVisionPredictionClient class and its methods
    mock_predictor = MagicMock()
    mock_predictor.detect_image.return_value = mock_result

    with patch('azure.cognitiveservices.vision.customvision.prediction.CustomVisionPredictionClient', 
              return_value=mock_predictor), \
         patch('msrest.authentication.ApiKeyCredentials'), \
         patch.dict(os.environ, {
            'CV_ENDPOINT': 'https://test-endpoint',
            'CV_KEY': 'test-key',
            'CV_PROJECT_ID': 'test-project',
            'CV_MODEL_NAME': 'test-model'
         }):
        # Test object_detection function
        result = function_app.object_detection(json.dumps({
            "image_data": img_base64
        }))
        
        # Verify the result
        assert isinstance(result, list)
        assert len(result) == 1
        prediction = json.loads(result[0])
        assert prediction["tag"] == "door"
        assert prediction["probability"] == 0.95

def test_summarize_results():
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

    # Mock OpenAI ChatCompletion
    mock_response = MagicMock()
    mock_response.choices = [MagicMock(message=MagicMock(content="Test summary"))]

    # Mock AzureOpenAI client
    mock_client = MagicMock()
    mock_client.chat.completions.create.return_value = mock_response

    with patch('openai.AzureOpenAI', return_value=mock_client), \
         patch.dict(os.environ, {
            'OPENAI_ENDPOINT': 'https://test-endpoint',
            'OPENAI_KEY': 'test-key',
            'OPENAI_MODEL': 'test-model'
         }):
        # Test summarize_results function
        result = function_app.summarize_results(json.dumps(test_payload))
        
        # Verify the result
        assert result == "Test summary"
        mock_client.chat.completions.create.assert_called_once()

if __name__ == '__main__':
    pytest.main([__file__])
