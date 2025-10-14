param (
    [Parameter(Mandatory=$true)][string]$SubscriptionId,
    [string]$Location = "eastus",
    [string]$TfStateResourceGroup = "zt-tfstate-rg",
    [string]$StorageAccountNamePrefix = "zt-tfstate",
    [string]$ContainerName = "zt-tfstate",
    [string]$InfraResourceGroup = "zt-infra-rg",
    [string]$ServicePrincipalName = "zt-sp-infra",
    [string]$Role = "Contributor"
)

function Run-Script {
    param (
        [string]$ScriptPath,
        [hashtable]$Arguments
    )

    $argsString = $Arguments.GetEnumerator() | ForEach-Object {
        "-$($_.Key) `"$($_.Value)`""
    } | Out-String

    Write-Host "`nRunning $ScriptPath with arguments: $argsString" -ForegroundColor Cyan

    $result = & $ScriptPath @Arguments

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Script $ScriptPath failed with exit code $LASTEXITCODE. Stopping execution."
        exit $LASTEXITCODE
    }

    return $result
}

# Ensure Azure login & select subscription once
Write-Host "Checking Azure login..." -ForegroundColor Cyan
az account show > $null 2>&1
if ($LASTEXITCODE -ne 0) { az login | Out-Null }
Write-Host "Setting subscription context to $SubscriptionId" -ForegroundColor Cyan
az account set --subscription $SubscriptionId
$active = az account show --query id -o tsv
if ($active -ne $SubscriptionId) { Write-Error "Failed to set subscription (active: $active)"; exit 1 }

# 1. Create Terraform backend RG and storage
Run-Script -ScriptPath ".\create-tfstate-backend.ps1" -Arguments @{
    Location = $Location
    TfStateResourceGroup = $TfStateResourceGroup
    StorageAccountNamePrefix = $StorageAccountNamePrefix
    ContainerName = $ContainerName
}

# 2. Create Infrastructure resource group
Run-Script -ScriptPath ".\create-infra-rg.ps1" -Arguments @{
    Location = $Location
    InfraResourceGroup = $InfraResourceGroup
}

# 3. Create Service Principal scoped to infra RG
Run-Script -ScriptPath ".\create-sp.ps1" -Arguments @{
    InfraResourceGroup    = $InfraResourceGroup
    ServicePrincipalName  = $ServicePrincipalName
    Role                  = $Role
}

Write-Host "`nAll steps completed successfully!" -ForegroundColor Green
Write-Host "You can now configure Terraform with the backend and SP credentials and start deploying your infrastructure."
