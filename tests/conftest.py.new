import os
import sys
import pytest
import importlib
import logging

# Add project root to Python path for importing modules
project_root = os.path.dirname(os.path.dirname(__file__))
sys.path.insert(0, project_root)
sys.path.insert(0, os.path.join(project_root, 'frontend'))

@pytest.fixture(scope="session")
def use_azure_functions_test_env():
    """Set up Azure Functions test environment."""
    os.environ.update({
        'AzureWebJobsScriptRoot': project_root,
        'AzureWebJobsStorage': 'UseDevelopmentStorage=true',
        'FUNCTIONS_WORKER_RUNTIME': 'python'
    })
