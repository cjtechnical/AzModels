# Azure Functions profile.ps1
# This script runs automatically during every cold start of the Function App.

$ErrorActionPreference = 'Stop'

# Function Apps do not reliably add an app-local Modules folder to the module
# search path. Put the bundled modules first so the worker cannot select a
# different version from its built-in or user module paths.
$LocalModulesPath = Join-Path -Path $PSScriptRoot -ChildPath 'Modules'
if (-not (Test-Path -LiteralPath $LocalModulesPath -PathType Container)) {
    throw "The bundled PowerShell modules folder was not found: $LocalModulesPath. Run scripts/ApplyModules.ps1."
}

$PathSeparator = [System.IO.Path]::PathSeparator
$ModulePaths = @($LocalModulesPath) + @($env:PSModulePath -split [regex]::Escape($PathSeparator))
$env:PSModulePath = ($ModulePaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique) -join $PathSeparator

# Import every module saved by scripts/ApplyModules.ps1 (Modules/<Name>/<Version>/<Name>.psd1).
# Az.Accounts goes first because the other Az modules depend on it.
$Manifests = Get-ChildItem -Path $LocalModulesPath -Directory | ForEach-Object {
    $ModuleName = $_.Name
    Get-ChildItem -Path $_.FullName -Directory | ForEach-Object {
        Join-Path -Path $_.FullName -ChildPath "$ModuleName.psd1"
    }
} | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    Sort-Object { if ((Split-Path $_ -Leaf) -eq 'Az.Accounts.psd1') { 0 } else { 1 } }

foreach ($ManifestPath in $Manifests) {
    Import-Module -Name $ManifestPath -Force -Global -ErrorAction Stop
}
