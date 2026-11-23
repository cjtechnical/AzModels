$configPath = Join-Path $PSScriptRoot "Config\Config.psd1"
$config = Import-PowerShellDataFile -Path $configPath
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$DeploymentZip = Join-Path $ProjectRoot "deployment.zip"

# $rg = "AzFinopsISFXX"
# $FunctionAppName = "ISFRationFunctionXX"


Push-Location $ProjectRoot
try {
  tar --exclude="scripts" --exclude="deployment.zip" -caf $DeploymentZip *
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to create deployment package: $DeploymentZip"
  }
}
finally {
  Pop-Location
}

# Push the zip archive straight to the Flex plan
az functionapp deployment source config-zip `
  --resource-group $config.ResourceGroup `
  --name $config.FunctionAppName `
  --src $DeploymentZip

az functionapp cors add --name $config.FunctionAppName --resource-group $config.ResourceGroup --allowed-origins "https://portal.azure.com"
