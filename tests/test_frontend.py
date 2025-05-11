import pytest
import os
import json
from unittest.mock import MagicMock, patch
from PIL import Image
import sys
import io

# Import the frontend app
from frontend.app import upload_to_blob, start_durable_function, poll_function_status, draw_bounding_boxes

def test_upload_to_blob():
    # Mock BlobServiceClient and its methods
    mock_blob_client = MagicMock()
    mock_blob_client.url = "https://teststorage.blob.core.windows.net/container/test.png"
    
    mock_container_client = MagicMock()
    mock_container_client.get_blob_client.return_value = mock_blob_client
    
    mock_blob_service = MagicMock()
    mock_blob_service.get_blob_client.return_value = mock_blob_client

    with patch('azure.storage.blob.BlobServiceClient.from_connection_string') as mock_blob_service_client:
        mock_blob_service_client.return_value = mock_blob_service
        
        # Create a test image
        test_image = Image.new('RGB', (100, 100), color = 'red')
        img_io = io.BytesIO()
        test_image.save(img_io, format='PNG')
        img_io.seek(0)
        
        # Test upload_to_blob function
        result = app.upload_to_blob(img_io, "test.png")
        
        # Verify the result
        assert result == "https://teststorage.blob.core.windows.net/container/test.png"
        mock_blob_client.upload_blob.assert_called_once()

def test_start_durable_function():
    mock_response = MagicMock()
    mock_response.json.return_value = {
        "statusQueryGetUri": "https://function.azurewebsites.net/runtime/webhooks/durabletask/instances/123"
    }
    mock_response.raise_for_status = MagicMock()

    with patch('requests.post') as mock_post:
        mock_post.return_value = mock_response
        
        # Test start_durable_function
        result = app.start_durable_function(
            "floorplan.png",
            "reference.png",
            "Analyze this floorplan"
        )
        
        # Verify the result
        assert result == "https://function.azurewebsites.net/runtime/webhooks/durabletask/instances/123"
        mock_post.assert_called_once()

def test_poll_function_status():
    mock_responses = [
        # First response - Running
        MagicMock(
            json=MagicMock(return_value={"runtimeStatus": "Running"})
        ),
        # Second response - Completed
        MagicMock(
            json=MagicMock(return_value={
                "runtimeStatus": "Completed",
                "output": {
                    "summary": "Test summary",
                    "detections": []
                }
            })
        )
    ]
    
    with patch('requests.get') as mock_get, \
         patch('time.sleep') as mock_sleep:  # Mock sleep to speed up tests
        mock_get.side_effect = mock_responses
        
        # Test poll_function_status
        result = app.poll_function_status("https://test-status-url")
        
        # Verify the result
        assert result["runtimeStatus"] == "Completed"
        assert result["output"]["summary"] == "Test summary"
        assert isinstance(result["output"]["detections"], list)
        assert mock_get.call_count == 2

def test_draw_bounding_boxes():
    # Create a test image
    test_image = Image.new('RGB', (100, 100), color = 'red')
    
    # Test detections with model_response
    test_detections = [{
        'tag': 'door',
        'probability': 0.95,
        'model_response': 'DOOR',
        'bounding_box': {
            'left': 0.1,
            'top': 0.1,
            'width': 0.2,
            'height': 0.2
        }
    }]
    
    # Test draw_bounding_boxes function
    result_image = app.draw_bounding_boxes(test_image, test_detections)
    
    # Verify the result is an image
    assert isinstance(result_image, Image.Image)
    assert result_image.size == (100, 100)

if __name__ == '__main__':
    pytest.main([__file__])
