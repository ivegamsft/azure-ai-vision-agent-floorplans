import os
import sys
import pytest
import importlib
import logging

# Add project root to Python path for importing modules
project_root = os.path.dirname(os.path.dirname(__file__))
sys.path.insert(0, project_root)
sys.path.insert(0, os.path.join(project_root, 'frontend'))
sys.path.insert(0, os.path.join(project_root, 'api'))

# Import test configuration
from tests.test_config import configure_test_environment

@pytest.fixture(scope="session")
def use_local_test_env():
    """Set up local development test environment."""
    os.environ.update({
        'AzureWebJobsScriptRoot': os.path.join(project_root, 'api'),
        'AzureWebJobsStorage': 'UseDevelopmentStorage=true',
        'FUNCTIONS_WORKER_RUNTIME': 'python',
        'OPENAI_API_VERSION': '2024-02-01'  # Added API version
    })

@pytest.fixture(scope="session")
def use_azure_functions_test_env():
    """Set up Azure deployed Functions test environment."""
    # Configure environment for Azure testing
    config = configure_test_environment()
