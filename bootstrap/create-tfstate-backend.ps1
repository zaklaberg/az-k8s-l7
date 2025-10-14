param (
    [Parameter(Mandatory=$true)][string]$Location,
    [Parameter(Mandatory=$true)][string]$TfStateResourceGroup,
    [Parameter(Mandatory=$true)][string]$StorageAccountNamePrefix,
    [Parameter(Mandatory=$true)][string]$ContainerName
)

# Login to Azure (if not already)
Write-Host "Logging in to Azure..."
az login | Out-Null

# Create resource group for terraform state backend
Write-Host "Creating resource group for terraform state: $TfStateResourceGroup in $Location..."
az group create --name $TfStateResourceGroup --location $Location | Out-Null

# Generate globally unique storage account name (max 24 chars, lowercase, no hyphens)
$randomSuffix = -join ((65..90) + (97..122) | Get-Random -Count 6 | ForEach-Object {[char]$_}) -replace '[A-Z]', {($_.Value.ToLower())}
$storageAccountName = ($StorageAccountNamePrefix + $randomSuffix) -replace '[^a-z0-9]', ''

if ($storageAccountName.Length -gt 24) {
    $storageAccountName = $storageAccountName.Substring(0, 24)
}

Write-Host "Creating storage account for terraform backend: $storageAccountName ..."
az storage account create `
    --name $storageAccountName `
    --resource-group $TfStateResourceGroup `
    --location $Location `
    --sku Standard_LRS `
    --kind StorageV2 `
    --access-tier Hot | Out-Null

# Get storage account key
Write-Host "Getting storage account key..."
$key = az storage account keys list `
    --resource-group $TfStateResourceGroup `
    --account-name $storageAccountName `
    --query '[0].value' -o tsv

# Create blob container for terraform state
Write-Host "Creating blob container: $ContainerName ..."
az storage container create `
    --name $ContainerName `
    --account-name $storageAccountName `
    --account-key $key | Out-Null

# Output backend config snippet for Terraform
Write-Host "`nTerraform backend configuration for azurerm:"
@"
terraform {
  backend "azurerm" {
    resource_group_name  = "$TfStateResourceGroup"
    storage_account_name = "$storageAccountName"
    container_name       = "$ContainerName"
    key                  = "aks.terraform.tfstate"
  }
}
"@
