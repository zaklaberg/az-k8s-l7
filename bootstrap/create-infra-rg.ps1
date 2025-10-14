param (
	[Parameter(Mandatory=$true)][string]$Location,
	[Parameter(Mandatory=$true)][string]$InfraResourceGroup
)

Write-Host "Ensuring you're logged in to Azure..." -ForegroundColor Cyan
az account show > $null 2>&1
if ($LASTEXITCODE -ne 0) {
	az login | Out-Null
}

Write-Host "Checking if resource group '$InfraResourceGroup' exists..." -ForegroundColor Cyan
$rgExists = az group exists --name $InfraResourceGroup | ConvertFrom-Json

if ($rgExists) {
	Write-Host "Resource group '$InfraResourceGroup' already exists. Skipping creation." -ForegroundColor Yellow
} else {
	Write-Host "Creating resource group '$InfraResourceGroup' in '$Location'..." -ForegroundColor Cyan
	az group create --name $InfraResourceGroup --location $Location | Out-Null
	Write-Host "Resource group created." -ForegroundColor Green
}

# Output JSON for downstream scripts if needed
$output = @{ InfraResourceGroup = $InfraResourceGroup; Location = $Location } | ConvertTo-Json -Compress
Write-Output $output
