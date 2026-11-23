# Downloads the PowerShell modules the function needs into <project root>/Modules.
# The Linux Flex Consumption plan does not support Managed Dependencies, so the
# modules must ship inside the deployment package.
#
# Add or remove entries in $Modules to fit your function. profile.ps1 imports
# everything found in the Modules folder, so no other file needs updating.

$Modules = @(
    @{ Name = "Az.Accounts"; Version = "5.5.3" }
    @{ Name = "Az.Storage";  Version = "9.6.0" }
)

$ProjectRoot   = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ModulesFolder = Join-Path $ProjectRoot "Modules"

# Start from a clean folder so stale module versions are not packaged.
if (Test-Path $ModulesFolder) { Remove-Item $ModulesFolder -Recurse -Force }
$null = New-Item -ItemType Directory -Path $ModulesFolder -Force

Write-Host "Saving modules to $ModulesFolder ..." -ForegroundColor Cyan

foreach ($Module in $Modules) {
    Write-Host "  $($Module.Name) $($Module.Version)"
    Save-Module -Name $Module.Name -RequiredVersion $Module.Version -Path $ModulesFolder -Repository PSGallery -Force
}

Write-Host "Done." -ForegroundColor Green
