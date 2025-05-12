# Set GitHub Secrets for Floorplans Vision Agent
# This script uses the GitHub CLI to set repository secrets and variables

# Check if GitHub CLI is installed
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI (gh) is not installed. Please install it from https://cli.github.com/"
    exit 1
}

# Check if logged in to GitHub
$loginStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Not logged in to GitHub. Please login using 'gh auth login'"
    gh auth login
}

# Repository name
$repoName = "ivegamsft/azure-ai-vision-agent-floorplans"

# Set repository secrets
Write-Host "Setting repository secrets..." -ForegroundColor Green
gh secret set AZURE_CLIENT_ID --body "a534ef91-4ebd-494e-b28f-eeb9207f89f8" --repo $repoName
gh secret set AZURE_TENANT_ID --body "62837751-4e48-4d06-8bcb-57be1a669b78" --repo $repoName
gh secret set AZURE_SUBSCRIPTION_ID --body "844eabcc-dc96-453b-8d45-bef3d566f3f8" --repo $repoName

# Set repository variables
Write-Host "Setting repository variables..." -ForegroundColor Green
gh variable set AZURE_FUNCTION_APP_NAME --body "func-ulc72fwx-zd61" --repo $repoName
gh variable set AZURE_RESOURCE_GROUP --body "rg-ulc72fwx-zd61-compute" --repo $repoName
gh variable set AZURE_WEBAPP_NAME --body "app-ulc72fwx-zd61" --repo $repoName

Write-Host "GitHub secrets and variables have been set successfully!" -ForegroundColor Green
Write-Host "Note: The service principal's client secret should be regenerated periodically for security."
