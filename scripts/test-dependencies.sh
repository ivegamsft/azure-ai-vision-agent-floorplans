#!/bin/bash

# Test script to validate that dependencies can be installed locally
# This mirrors the dependency installation steps in the GitHub Actions workflows

set -e

echo "Starting dependency validation test..."

# Create test virtual environment
echo "Creating test virtual environment..."
python3.10 -m venv test_venv || python -m venv test_venv
source test_venv/bin/activate

# Test API dependencies
echo "Testing API dependencies..."
pip install --upgrade pip
pip install --timeout 60 --retries 3 -r api/requirements.txt

echo "Validating API imports..."
cd api
python -c "import azure.functions; import azure.durable_functions; import openai; print('✅ Function dependencies validated successfully')"
cd ..

# Test Frontend dependencies  
echo "Testing Frontend dependencies..."
cd frontend
pip install --timeout 60 --retries 3 -r requirements.txt

echo "Validating Frontend imports..."
python -c "import streamlit; import azure.storage.blob; import azure.identity; print('✅ Frontend dependencies validated successfully')"
cd ..

# Cleanup
echo "Cleaning up test environment..."
deactivate
rm -rf test_venv

echo "✅ All dependency tests passed!"