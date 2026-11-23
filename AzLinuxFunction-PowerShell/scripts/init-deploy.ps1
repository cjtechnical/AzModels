$configPath = Join-Path $PSScriptRoot "Config\Config.psd1"
$config = Import-PowerShellDataFile -Path $configPath
# 1. Create a Resource Group
az group create --name $config.ResourceGroup --location $config.Location

# 2. Create the required Storage Account (must be lowercase, letters/numbers only)
az storage account create `
  --name $config.StorageAccount `
  --resource-group $config.ResourceGroup `
  --location $config.Location `
  --sku Standard_LRS

# 3. Create the Flex Consumption Function App (Linux PowerShell 7.4)
az functionapp create `
  --resource-group $config.ResourceGroup `
  --name $config.FunctionAppName `
  --storage-account $config.StorageAccount `
  --flexconsumption-location $config.Location `
  --runtime powershell `
  --runtime-version 7.4 `
  --functions-version 4
