param($Timer, $TriggerMetadata)

# -----------------------------------------------------------------------------
# Hello World template for an Azure Linux (Flex Consumption) PowerShell Function.
#
# 1. Authenticates with the Function App's system-assigned managed identity.
# 2. Writes a "Hello World" text file to the worker's temp directory.
# 3. Uploads that file to a blob container in the storage account defined in
#    scripts/Config/Config.psd1 (StorageAccount).
#
# Bundled modules (Modules/) are imported by profile.ps1 on cold start.
# -----------------------------------------------------------------------------

$ErrorActionPreference = "Stop"

$ContainerName = "function-outputs"

# -----------------------------------------------------------------------------
# Resolve the storage account name.
#
# scripts/ is not deployed, so in Azure the value comes from the
# STORAGE_ACCOUNT_NAME app setting (set from Config.psd1 by Set-Permissions.ps1).
# Locally, fall back to reading Config.psd1 directly.
# -----------------------------------------------------------------------------
$StorageAccountName = $env:STORAGE_ACCOUNT_NAME

if ([string]::IsNullOrWhiteSpace($StorageAccountName)) {
    $ConfigPath = Join-Path (Split-Path -Parent $PSScriptRoot) "scripts/Config/Config.psd1"

    if (Test-Path -LiteralPath $ConfigPath -PathType Leaf) {
        $Config = Import-PowerShellDataFile -Path $ConfigPath
        $StorageAccountName = $Config.StorageAccount
    }
}

if ([string]::IsNullOrWhiteSpace($StorageAccountName)) {
    throw "Storage account name not found. Set the STORAGE_ACCOUNT_NAME app setting (run scripts/Set-Permissions.ps1) or StorageAccount in scripts/Config/Config.psd1."
}

if (-not (Get-Command New-AzStorageContext -ErrorAction SilentlyContinue)) {
    throw "Az.Storage is not loaded. Run scripts/ApplyModules.ps1 and redeploy so the Modules folder is included."
}

# -----------------------------------------------------------------------------
# 1. Authenticate with the managed identity
# -----------------------------------------------------------------------------
Disable-AzContextAutosave -Scope Process | Out-Null
Connect-AzAccount -Identity -Environment AzureCloud | Out-Null

# -----------------------------------------------------------------------------
# 2. Create the Hello World file locally
# -----------------------------------------------------------------------------
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$FileName  = "hello-world-$Timestamp.txt"
$LocalFile = Join-Path ([System.IO.Path]::GetTempPath()) $FileName

"Hello World from Azure Functions! Generated $(Get-Date -Format o)" |
    Set-Content -Path $LocalFile -Encoding UTF8

Write-Host "Created local file: $LocalFile"

# -----------------------------------------------------------------------------
# 3. Upload the file to blob storage
#    Requires the "Storage Blob Data Contributor" role (Set-Permissions.ps1).
# -----------------------------------------------------------------------------
$StorageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount

if (-not (Get-AzStorageContainer -Name $ContainerName -Context $StorageContext -ErrorAction SilentlyContinue)) {
    Write-Host "Creating container: $ContainerName"
    $null = New-AzStorageContainer -Name $ContainerName -Context $StorageContext
}

$null = Set-AzStorageBlobContent `
    -File $LocalFile `
    -Container $ContainerName `
    -Blob $FileName `
    -Context $StorageContext `
    -Force

Remove-Item -LiteralPath $LocalFile -Force -ErrorAction SilentlyContinue

Write-Host "Uploaded $FileName to $StorageAccountName/$ContainerName at $(Get-Date)"
