import streamlit as st
import requests
import time
from azure.storage.blob import BlobServiceClient
import uuid
import json
from datetime import datetime
from PIL import Image, ImageDraw
import os
from dotenv import load_dotenv

load_dotenv()

# --- Azure Config ---
STORAGE_CONN_STR = os.getenv("STORAGE_CONN_STR")
CONTAINER_NAME = os.getenv("CONTAINER_NAME")
FUNCTION_START_URL = os.getenv("FUNCTION_START_URL")
# FUNCTION_KEY = "your_function_key" # optional if not anonymous

# --- Upload Helper ---
def upload_to_blob(file, blob_name):
    blob_service = BlobServiceClient.from_connection_string(STORAGE_CONN_STR)
    blob_client = blob_service.get_blob_client(container=CONTAINER_NAME, blob=blob_name)
    blob_client.upload_blob(file, overwrite=True)
    return blob_client.url

# --- Trigger Function ---
def start_durable_function(fp_url, ref_url, prompt):
    data = {
        "container": CONTAINER_NAME,
        "filename": fp_url,
        "reference_filename": ref_url,
        "analyze_prompt": prompt,
    }
    # headers = {"x-functions-key": FUNCTION_KEY}  # Optional
    response = requests.post(FUNCTION_START_URL, json=data)
    response.raise_for_status()
    status_query_url = response.json()["statusQueryGetUri"]
    return status_query_url

# --- Poll Function ---
def poll_function_status(status_url):
    while True:
        res = requests.get(status_url)
        res.raise_for_status()
        result = res.json()
        if result["runtimeStatus"] in ["Completed", "Failed", "Terminated"]:
            return result
        time.sleep(5)  # A

def draw_bounding_boxes(image, detections):
    """Draw bounding boxes on the image based on model detections."""
    draw = ImageDraw.Draw(image)
    img_width, img_height = image.size
    for detection in detections:
        bbox = detection["bounding_box"]
        # Convert normalized coordinates to absolute pixel values
        left = int(bbox["left"] * img_width)
        top = int(bbox["top"] * img_height)
        width = int(bbox["width"] * img_width)
        height = int(bbox["height"] * img_height)
        # Draw rectangle
        draw.rectangle([left, top, left + width, top + height], outline="red", width=3)
        # Annotate with label
        draw.text((left, top - 10), detection["model_response"], fill="red")
    return image

def crop_detected_regions(image, detections):
    """Crop regions from the image based on bounding boxes."""
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


st.set_page_config(layout="wide", page_title="Azure AI Vision Agent Floorplans", page_icon=":house_with_garden:")
st.title("Azure AI Vision Agent Floorplans")
tab1, tab2 = st.tabs(["Settings", "Floor plan Analysis Output"])

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
                fp_url = upload_to_blob(fp_image, fp_name)
                ref_url = upload_to_blob(ref_image, ref_name)
            
            with st.spinner("Starting Azure Durable Function..."):
                status_url = start_durable_function(fp_name, ref_name, prompt)

            with st.spinner("Waiting for analysis to complete..."):
                result = poll_function_status(status_url)
        with topcol1:
            st.success("Analysis completed successfully!")
        if result and result["runtimeStatus"] == "Completed":
            with tab2:
                    if result["runtimeStatus"] == "Completed":
                        st.success("Analysis completed successfully!")
                        cola, colb = st.columns([2.5,1.5])
                        with cola:
                            st.subheader("Object Detection Output")
                            image = Image.open(fp_image)
                            detections = result["output"]
                            image_with_boxes = draw_bounding_boxes(image, detections)
                            st.image(image_with_boxes, caption="Detected Objects")
                        with colb:
                            cropped_images = crop_detected_regions(image, result["output"])
                            st.subheader("Outputs")
                            for cropped_img, detection in cropped_images:
                                sub_col1, sub_col2 = st.columns([0.5,2])
                                with sub_col1:
                                    st.image(cropped_img, 
                                             width=50)
                                with sub_col2:
                                    st.json(detection)
                            st.subheader("Raw Output")
                            st.json(result["output"])  # customize based on your actual function output
                    else:
                        st.error(f"Function failed with status: {result['runtimeStatus']}")
                        st.json(result)