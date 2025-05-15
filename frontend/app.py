import streamlit as st
import requests
import time
from azure.storage.blob import BlobServiceClient
from azure.identity import DefaultAzureCredential, ManagedIdentityCredential
import uuid
import json
from datetime import datetime
from PIL import Image, ImageDraw
import os
from dotenv import load_dotenv

# Set page configuration first
st.set_page_config(layout="wide", page_title="Azure AI Vision Agent Floorplans", page_icon=":house_with_garden:")

load_dotenv()

class FloorplanApp:
    def __init__(self):
        # Try to get the storage account name from connection string or environment
        self.STORAGE_CONN_STR = os.getenv("STORAGE_CONNECTION_STRING")
        self.STORAGE_ACCOUNT = os.getenv("STORAGE_ACCOUNT_NAME")
        self.MANAGED_IDENTITY_CLIENT_ID = os.getenv("MANAGED_IDENTITY_CLIENT_ID")
          # Set container name
        self.CONTAINER_NAME = os.getenv("CONTAINER_NAME", "floorplans")
        
        if not self.STORAGE_ACCOUNT and self.STORAGE_CONN_STR:
            try:
                # Extract account name from connection string
                self.STORAGE_ACCOUNT = dict(pair.split('=', 1) for pair in self.STORAGE_CONN_STR.split(';'))['AccountName']
            except:
                st.error("Could not determine storage account name")
        
        # Set function URL with default for local development
        function_app_url = os.getenv("FUNCTION_APP_URL", "http://localhost:7071")
        self.FUNCTION_START_URL = function_app_url.rstrip('/') + "/api/orchestrators/vision_agent_orchestrator"
        st.info(f"Using Function URL: {self.FUNCTION_START_URL}")

    def get_blob_service_client(self):
        try:
            # For local development, try connection string first
            if self.STORAGE_CONN_STR:
                st.info("📝 Using connection string authentication...")
                try:
                    client = BlobServiceClient.from_connection_string(self.STORAGE_CONN_STR)
                    client.get_service_properties()
                    st.info("✅ Successfully connected with connection string")
                    return client
                except Exception as e:
                    st.error(f"❌ Connection string auth failed: {str(e)}")

            # For local development with Azure CLI or Azure-hosted scenarios
            if self.STORAGE_ACCOUNT:
                st.info(f"📝 Attempting Azure authentication for {self.STORAGE_ACCOUNT}...")
                try:
                    # DefaultAzureCredential tries:
                    # 1. Environment variables
                    # 2. Managed Identity
                    # 3. Azure CLI
                    # 4. Visual Studio Code credentials
                    credential = DefaultAzureCredential()
                    
                    client = BlobServiceClient(
                        account_url=f"https://{self.STORAGE_ACCOUNT}.blob.core.windows.net",
                        credential=credential
                    )
                    
                    # Test the connection
                    client.get_service_properties()
                    st.info("✅ Successfully connected using Azure authentication")
                    return client
                except Exception as e:
                    st.error(f"❌ Azure authentication failed: {str(e)}")
                    if hasattr(e, 'message'):
                        st.error(f"Error details: {e.message}")
            
            st.error("❌ No valid authentication method available")
            return None
            
        except Exception as e:
            st.error(f"❌ Error creating blob client: {str(e)}")
            if hasattr(e, 'message'):
                st.error(f"Error message: {e.message}")
            return None

    def upload_to_blob(self, file, blob_name):
        max_retries = 3
        retry_delay = 1  # seconds
        
        for attempt in range(max_retries):
            try:
                st.info(f"Upload attempt {attempt + 1} of {max_retries} for {blob_name}")
                
                # Get the blob service client
                blob_service_client = self.get_blob_service_client()
                if not blob_service_client:
                    st.error("Failed to get blob service client")
                    if attempt < max_retries - 1:
                        st.info(f"Retrying in {retry_delay} seconds...")
                        time.sleep(retry_delay)
                        retry_delay *= 2  # Exponential backoff
                        continue
                    return None
                
                # Create the blob client for the container
                st.info(f"Creating blob client for container: {self.CONTAINER_NAME}")
                try:
                    container_client = blob_service_client.get_container_client(self.CONTAINER_NAME)
                    # Test container access
                    container_client.get_container_properties()
                    st.info("✅ Successfully accessed container")
                except Exception as container_e:
                    st.error(f"❌ Container access error ({type(container_e).__name__}): {str(container_e)}")
                    if hasattr(container_e, 'error_code'):
                        st.error(f"Container error code: {container_e.error_code}")
                    if attempt < max_retries - 1:
                        st.info(f"Retrying in {retry_delay} seconds...")
                        time.sleep(retry_delay)
                        retry_delay *= 2
                        continue
                    return None
                
                # Create blob client and upload
                blob_client = container_client.get_blob_client(blob_name)
                st.info("Starting blob upload...")
                
                # Get file size and type info
                file.seek(0, 2)  # Seek to end
                file_size = file.tell()
                file.seek(0)  # Reset to beginning
                content_type = getattr(file, 'type', 'application/octet-stream')
                
                st.info(f"Uploading file: size={file_size} bytes, type={content_type}")
                
                # Upload with metadata
                from azure.storage.blob import ContentSettings
                blob_client.upload_blob(
                    file,
                    overwrite=True,
                    content_settings=ContentSettings(
                        content_type=content_type
                    ),
                    metadata={
                        'uploaded_by': 'vision_agent_frontend',
                        'original_filename': getattr(file, 'name', 'unknown'),
                        'upload_time': datetime.now().isoformat()
                    }
                )
                
                st.info(f"✅ Successfully uploaded blob: {blob_name}")
                url = blob_client.url
                st.info(f"Blob URL: {url}")
                return url
                
            except Exception as e:
                st.error(f"❌ Error uploading to blob storage (Attempt {attempt + 1}) ({type(e).__name__}): {str(e)}")
                if hasattr(e, 'error_code'):
                    st.error(f"Error code: {e.error_code}")
                if hasattr(e, 'response'):
                    st.error(f"Response status: {e.response.status_code}")
                if hasattr(e, 'response'):
                    st.error(f"Response text: {e.response.text}")
                if hasattr(e, '__dict__'):
                    st.error(f"Error details: {e.__dict__}")
                
                if attempt < max_retries - 1:
                    st.info(f"Retrying in {retry_delay} seconds...")
                    time.sleep(retry_delay)
                    retry_delay *= 2
                else:
                    st.error("❌ Max retries reached. Upload failed.")
                    return None
        
        return None

    def start_durable_function(self, filename, reference_filename, analyze_prompt):
        try:
            response = requests.post(
                self.FUNCTION_START_URL,
                json={
                    "container": self.CONTAINER_NAME,
                    "filename": filename,
                    "reference_filename": reference_filename,
                    "analyze_prompt": analyze_prompt
                }
            )
            response.raise_for_status()
            return response.json()["statusQueryGetUri"]
        except Exception as e:
            st.error(f"Error starting function: {e}")
            return None

    def poll_function_status(self, status_url, timeout=300):
        start_time = time.time()
        while True:
            if time.time() - start_time > timeout:
                st.error("Function timed out")
                return None
                
            try:
                response = requests.get(status_url)
                status = response.json()
                
                if status["runtimeStatus"] == "Completed":
                    return status
                elif status["runtimeStatus"] == "Failed":
                    st.error("Function failed")
                    return None
                    
                time.sleep(5)
            except Exception as e:
                st.error(f"Error polling function status: {e}")
                return None

    def draw_bounding_boxes(self, image, detections):
        draw = ImageDraw.Draw(image)
        width, height = image.size
        
        for detection in detections:
            box = detection['bounding_box']
            left = box['left'] * width
            top = box['top'] * height
            right = left + (box['width'] * width)
            bottom = top + (box['height'] * height)
            
            # Draw rectangle
            draw.rectangle([left, top, right, bottom], outline="red", width=3)
            
            # Draw label
            label = f"{detection['tag']} ({detection['probability']:.2f})"
            draw.text((left, top-20), label, fill="red")
            
        return image

    def crop_detected_regions(self, image, detections):
        cropped_images = []
        img_width, img_height = image.size
        for detection in detections:
            bbox = detection["bounding_box"]
            left = int(bbox["left"] * img_width)
            top = int(bbox["top"] * img_height)
            width = int(bbox["width"] * img_width)
            height = int(bbox["height"] * img_height)
            cropped_img = image.crop((left, top, left + width, top + height))
            cropped_images.append((cropped_img, detection))
        return cropped_images

# Rest of the UI code...
app = FloorplanApp()

st.title("Azure AI Vision Agent Floorplans")
tab1, tab2, tab3 = st.tabs(["Settings", "Floor plan Analysis Summary", "Floor plan Analysis Output"])

with tab1:
    topcol1, topcol2 = st.columns([0.2, 0.5], gap="small")
    with topcol1:
        run_analysis = st.button("Run Analysis")       

    col1, col2, col3 = st.columns(3)
    with col1:
        st.subheader("Floor Plan upload")
        fp_image = st.file_uploader("Upload Floor Plan", type=["jpg", "jpeg", "png"], key="floorplan")
            # Store the uploaded image in session state
        if fp_image is not None:
            st.image(Image.open(st.session_state.floorplan), caption="Uploaded Floor Plan")
            
    with col2:
        st.subheader("Reference Image upload")
        ref_image = st.file_uploader("Upload Reference Image", type=["jpg", "jpeg", "png"], key="legend")
        if ref_image is not None:
            st.image(Image.open(st.session_state.legend), caption="Uploaded Reference")
    with col3:
        st.subheader("Analyze Prompt")
        prompt_placeholder = ""
        prompt_file_path = os.path.join(os.getcwd(), "prompt.txt")
        if os.path.exists(prompt_file_path):
            with open(prompt_file_path, "r") as f:
                prompt_placeholder = f.read()
        prompt = st.text_area("Prompt",prompt_placeholder, height=500, key="prompt")
        save_prompt = st.button("Save Prompt")
        
        if save_prompt:
            # Create a file with the prompt
            entry = {
                "timestamp": datetime.now().isoformat(),
                "prompt": prompt
            }
            prompts_file_path = os.path.join(os.getcwd(), "prompts.jsonl")
            with open(prompts_file_path, "a") as f:
                f.write(json.dumps(entry) + "\n")
            st.success("Prompt saved successfully!")

    result = None  # Initialize result to avoid undefined reference

    if run_analysis and fp_image and ref_image and prompt:
        with topcol1:
            with st.spinner("Uploading files to Azure Blob Storage..."):
                fp_name = f"floorplan-{uuid.uuid4()}.png"
                ref_name = f"reference-{uuid.uuid4()}.png"
                fp_url = app.upload_to_blob(fp_image, fp_name)
                ref_url = app.upload_to_blob(ref_image, ref_name)
            
            with st.spinner("Starting Azure Durable Function..."):
                status_url = app.start_durable_function(fp_name, ref_name, prompt)

            with st.spinner("Waiting for analysis to complete..."):
                result = app.poll_function_status(status_url)
            
            with st.spinner("Process completed"):
                st.success("Analysis completed successfully!")
            
        if result and result["runtimeStatus"] == "Completed":
            with tab2:
                st.subheader("Summary")
                st.markdown(result["output"]["summary"])

            with tab3:
                cola, colb = st.columns([2.5,1.5])
                with cola:
                    st.subheader("Detailed Analysis")
                    # Load and cache image
                    if 'processed_image' not in st.session_state:
                        image = Image.open(fp_image)
                        detections = result["output"]["detections"]
                        image_with_boxes = app.draw_bounding_boxes(image, detections)
                        st.session_state.processed_image = image_with_boxes
                        st.session_state.original_image = image
                    
                    st.subheader("Object Detection Output")
                    st.image(st.session_state.processed_image, caption="Detected Objects")

                with colb:
                    if 'original_image' in st.session_state:
                        cropped_images = app.crop_detected_regions(st.session_state.original_image, result["output"]["detections"])
                        st.subheader("Outputs")
                        for cropped_img, detection in cropped_images:
                            sub_col1, sub_col2 = st.columns([0.5,2])
                            with sub_col1:
                                st.image(cropped_img, width=50)
                            with sub_col2:
                                st.json(detection)
                        st.subheader("Raw Output")
                        st.json(result["output"])
        else:
            if result:  # Only show error if result exists but failed
                st.error(f"Function failed with status: {result['runtimeStatus']}")
                st.json(result)
