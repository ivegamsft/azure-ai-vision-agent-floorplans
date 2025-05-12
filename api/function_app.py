import azure.functions as func
import azure.durable_functions as df
from azure.cognitiveservices.vision.customvision.prediction import CustomVisionPredictionClient  
from azure.storage.blob import BlobServiceClient
from msrest.authentication import ApiKeyCredentials
from azure.identity import DefaultAzureCredential, ManagedIdentityCredential
import os
import json
import base64
from openai import AzureOpenAI
from PIL import Image
from io import BytesIO
from pydantic import BaseModel

# Initialize the Azure credential
credential = DefaultAzureCredential()

class BoundingBox(BaseModel):
    left: float
    top: float
    width: float
    height: float

class Prediction(BaseModel):
    tag: str
    probability: float
    bounding_box: BoundingBox

myApp = df.DFApp(http_auth_level=func.AuthLevel.ANONYMOUS)

# An HTTP-triggered function with a Durable Functions client binding
@myApp.route(route="orchestrators/{functionName}")
@myApp.durable_client_input(client_name="client")
async def http_start(req: func.HttpRequest, client):
    function_name = req.route_params.get('functionName')
    payload = json.loads(req.get_body())
    instance_id = await client.start_new(function_name, client_input=payload)
    response = client.create_check_status_response(req, instance_id)
    return response

# Orchestrator
@myApp.orchestration_trigger(context_name="context")
def vision_agent_orchestrator(context):
    payload = context.get_input()
    container = payload.get("container")
    filename = payload.get("filename")
    analyze_prompt = payload.get("analyze_prompt")
    reference_filename = payload.get("reference_filename")
    prediction_threshold = payload.get("prediction_threshold", 0.5)

    ## Read the candidate image and reference image from blob storage
    read_tasks = [context.call_activity("read_image",
                                        json.dumps({"container": container, "filename": filename}))
                                        for filename in [filename, reference_filename]]
    
    read_results = yield context.task_all(read_tasks)
    b64_image = read_results[0]
    b64_reference_image = read_results[1]
    
    ## Perform object detection on the candidate image
    retry_options = df.RetryOptions(200,3)
    predictions = yield context.call_activity("object_detection", json.dumps({"image_data": b64_image}))
    detections = [Prediction.model_validate_json(pred) for pred in predictions]

    ### Make a call to Azure OpenAI to analyze the detected objects
    binary_image_data = base64.b64decode(b64_image)
    image = Image.open(BytesIO(binary_image_data))

    tasks = []
    for prediction in detections:
        # Crop the image based on the bounding box
        if prediction.probability > prediction_threshold:
            buffered = BytesIO()

            buffer = 10  # Buffer around the bounding box
            left = max(0, int(prediction.bounding_box.left * image.width) - buffer)
            top = max(0, int(prediction.bounding_box.top * image.height) - buffer)
            right = min(image.width, int((prediction.bounding_box.left + prediction.bounding_box.width) * image.width) + buffer)
            bottom = min(image.height, int((prediction.bounding_box.top + prediction.bounding_box.height) * image.height) + buffer)
            
            cropped_image = image.crop((left, top, right, bottom))
            cropped_image.convert('RGB').save(buffered, format="JPEG")
            
            # Convert the cropped image to base64
            img_str = base64.b64encode(buffered.getvalue()).decode("utf-8")
            base64_url = f"data:image/jpeg;base64,{img_str}"
            b64_reference_image_url = f"data:image/jpeg;base64,{b64_reference_image}"
            detection_payload = json.dumps({
                "bounding_box": {
                    "left": prediction.bounding_box.left,
                    "top": prediction.bounding_box.top,
                    "width": prediction.bounding_box.width,
                    "height": prediction.bounding_box.height
                },
                "tag": prediction.tag,
                "probability": prediction.probability,
                "image": base64_url,
                "reference_img": b64_reference_image_url,
                "analyze_prompt": analyze_prompt})
            
            tasks.append(context.call_activity("azure_openai_processing", detection_payload))
    
    object_results = yield context.task_all(tasks)
    
    # Add summarization step
    summary_payload = {
        "object_results": object_results,
        "predictions": predictions,
        "analyze_prompt": analyze_prompt
    }
    summary = yield context.call_activity("summarize_results", json.dumps(summary_payload))
    
    # Add summary to results
    final_results = {
        "detections": object_results,
        "summary": summary
    }
    
    return final_results

# Activity
@myApp.activity_trigger(input_name="activitypayload")
def read_image(activitypayload):
    data = json.loads(activitypayload)
    container = data.get("container")
    filename = data.get("filename")

    # Get the storage account name from the connection string
    storage_account_name = os.environ.get("STORAGE_ACCOUNT_NAME")
    storage_account_url = f"https://{storage_account_name}.blob.core.windows.net"

    # Use managed identity to authenticate
    blob_service_client = BlobServiceClient(
        account_url=storage_account_url,
        credential=credential
    )
    blob_client = blob_service_client.get_blob_client(container=container, blob=filename)
    image_bytes = blob_client.download_blob().readall()

    return base64.b64encode(image_bytes).decode("utf-8")

@myApp.activity_trigger(input_name="activitypayload")
def object_detection(activitypayload):
    img_data = json.loads(activitypayload).get("image_data")
    image_data = base64.b64decode(img_data)

    endpoint = os.environ["CV_ENDPOINT"]
    project_id = os.environ["CV_PROJECT_ID"]
    model_name = os.environ["CV_MODEL_NAME"]

    # Create Custom Vision client with managed identity
    credentials = ApiKeyCredentials(in_headers={"Prediction-key": os.environ["CV_KEY"]})  # Custom Vision still requires API key
    predictor = CustomVisionPredictionClient(endpoint, credentials)
    results = predictor.detect_image(project_id, 
                                     model_name, 
                                     image_data)

    predictions = [
        Prediction(
            tag=p.tag_name,
            probability=p.probability,
            bounding_box=BoundingBox(
                left=p.bounding_box.left,
                top=p.bounding_box.top,
                width=p.bounding_box.width,
                height=p.bounding_box.height
            )
        ) for p in results.predictions
    ]

    return [pred.json() for pred in predictions]

@myApp.activity_trigger(input_name="activitypayload")
def azure_openai_processing(activitypayload):
    # Use managed identity for Azure OpenAI
    client = AzureOpenAI(
        azure_endpoint=os.environ["OPENAI_ENDPOINT"],
        api_version="2024-02-01",
        azure_ad_token_provider=credential
    )
    prompt ="""
    Here's an image of a symbol and a legend
    please match the symbol to the legend and give me the name of the symbol in the legend.
    Use the exact symbol name as it appears in the legend, all in uppercase
    only return the name of the symbol or No Match if there is no match
    
    Here is the legend
"""
    reference_img = json.loads(activitypayload).get("reference_img")
    detected_img = json.loads(activitypayload).get("image")
    analyze_prompt = json.loads(activitypayload).get("analyze_prompt")
    if analyze_prompt:
        sys_prompt = analyze_prompt
    else:
        sys_prompt = prompt

    messages = [
       {
        "role": "user",
        "content": [
          {"type": "text", "text": sys_prompt},
          {
            "type": "image_url",
            "image_url": {
              "url": reference_img,
            },
          }
        ],
      },
      {
                "role": "user",
                "content": [
                    {"type": "text", "text": "Here is the symbol and the legend"},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": detected_img,
                            "detail": "high"
                        },
                    }
                ],
            }
    ]

    response = client.chat.completions.create(
        model=os.environ["OPENAI_MODEL"],
        messages=messages
    )

    return {"model_response":response.choices[0].message.content,
            "bounding_box": json.loads(activitypayload).get("bounding_box"),
            "tag": json.loads(activitypayload).get("tag"),
            "probability": json.loads(activitypayload).get("probability")}

@myApp.activity_trigger(input_name="activitypayload")
def summarize_results(activitypayload):
    data = json.loads(activitypayload)
    object_results = data.get("object_results", [])
    analyze_prompt = data.get("analyze_prompt", "")

    # Create a summary prompt for OpenAI
    detection_summary = "\n".join([
        f"- Found {result['tag']} (confidence: {result['probability']:.2%}) identified as: {result['model_response']}"
        for result in object_results
    ])

    # Use managed identity for Azure OpenAI
    client = AzureOpenAI(
        azure_endpoint=os.environ["OPENAI_ENDPOINT"],
        api_version="2024-02-01",
        azure_ad_token_provider=credential
    )

    summary_prompt = f"""Given the following floor plan analysis results:

{detection_summary}

Please provide:
1. A concise summary of the detected elements
2. Any patterns or notable observations
3. Potential recommendations or concerns based on the layout

Keep the response clear and structured."""

    messages = [
        {
            "role": "system",
            "content": "You are an expert in analyzing floor plans and architectural layouts. Provide clear, professional insights."
        },
        {
            "role": "user",
            "content": summary_prompt
        }
    ]

    response = client.chat.completions.create(
        model=os.environ["OPENAI_MODEL"], 
        messages=messages,
        temperature=0.7,
        max_tokens=500
    )

    return response.choices[0].message.content

