param (
	[Parameter(Mandatory=$true)][string]$InfraResourceGroup,
	[Parameter(Mandatory=$true)][string]$ServicePrincipalName,
	[Parameter(Mandatory=$true)][string]$Role
)

Write-Host "Ensuring Azure CLI is logged in..." -ForegroundColor Cyan
az account show > $null 2>&1
if ($LASTEXITCODE -ne 0) { az login | Out-Null }

# Get subscription + tenant
$subId = az account show --query id -o tsv
$tenantId = az account show --query tenantId -o tsv

Write-Host "Subscription: $subId" -ForegroundColor Gray
Write-Host "Tenant: $tenantId" -ForegroundColor Gray

# Ensure RG exists
$rgExists = az group exists --name $InfraResourceGroup | ConvertFrom-Json
if (-not $rgExists) {
	Write-Error "Resource group '$InfraResourceGroup' does not exist. Run create-infra-rg.ps1 first."; exit 1
}

Write-Host "Looking for existing service principal '$ServicePrincipalName'..." -ForegroundColor Cyan
$existing = az ad sp list --display-name $ServicePrincipalName --query '[0]' -o json | ConvertFrom-Json

$spPassword = $null
if ($existing) {
	Write-Host "Service principal exists. Re-using it." -ForegroundColor Yellow
	$appId = $existing.appId
} else {
	Write-Host "Creating new service principal '$ServicePrincipalName'..." -ForegroundColor Cyan
	$created = az ad sp create-for-rbac --name $ServicePrincipalName --skip-assignment --query '{appId:appId, password:password}' -o json | ConvertFrom-Json
	$appId = $created.appId
	$spPassword = $created.password
	Write-Host "Service principal created." -ForegroundColor Green
}

# Scope role assignment to RG
$scope = "/subscriptions/$subId/resourceGroups/$InfraResourceGroup"

Write-Host "Ensuring role assignment ($Role) on scope $scope ..." -ForegroundColor Cyan
$assigned = az role assignment list --assignee $appId --scope $scope --query "[?roleDefinitionName=='$Role'] | [0]" -o json | ConvertFrom-Json
if (-not $assigned) {
	az role assignment create --assignee $appId --role $Role --scope $scope | Out-Null
	Write-Host "Role assignment created." -ForegroundColor Green
} else {
	Write-Host "Role assignment already exists." -ForegroundColor Yellow
}

# If we reused SP, optionally create a new password (client secret) so user has a credential
if (-not $spPassword) {
	Write-Host "Creating a new client secret for existing SP (valid 1 year)..." -ForegroundColor Cyan
	$now = Get-Date
	$end = $now.AddYears(1).ToString('yyyy-MM-ddTHH:mm:ssZ')
	$spPassword = az ad app credential reset --id $appId --years 1 --query password -o tsv
}

Write-Host "\nService Principal details for Terraform (store these securely):" -ForegroundColor Green
Write-Host "ARM_CLIENT_ID=$appId"
Write-Host "ARM_CLIENT_SECRET=$spPassword"
Write-Host "ARM_TENANT_ID=$tenantId"
Write-Host "ARM_SUBSCRIPTION_ID=$subId"

# Output JSON for consumption by other tooling
$output = @{ appId = $appId; clientSecret = $spPassword; tenantId = $tenantId; subscriptionId = $subId } | ConvertTo-Json -Compress
Write-Output $output
