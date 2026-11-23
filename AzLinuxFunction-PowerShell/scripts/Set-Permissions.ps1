$configPath = Join-Path $PSScriptRoot "Config\Config.psd1"
$config = Import-PowerShellDataFile -Path $configPath

$rg = $config.ResourceGroup
$storageAccount = $config.StorageAccount
$MgtGroup = $config.MgtGroup

# 1. Get your Azure Subscription ID
$subId = az account show --query id -o tsv


# 2. Turn on System Assigned Managed Identity for your Flex App
$principalId= az functionapp identity assign `
  --resource-group $config.ResourceGroup `
  --name $config.FunctionAppName `
  --query principalId -o tsv

# 3. Add explicit Environment Variables so your script knows its own metadata context
az functionapp config appsettings set `
  --resource-group $config.ResourceGroup `
  --name $config.FunctionAppName `
  --settings "STORAGE_ACCOUNT_NAME=$($config.StorageAccount)" "RESOURCE_GROUP_NAME=$($config.ResourceGroup)"

# 4. Assign the storage role to the app's identity scope
az role assignment create `
  --assignee $principalId `
  --role "Storage Blob Data Contributor" `
  --scope "/subscriptions/$subId/resourceGroups/$rg/providers/Microsoft.Storage/storageAccounts/$storageAccount"

  az role assignment create `
  --assignee $principalId `
  --role "Reader" `
  --scope "/providers/Microsoft.Management/managementGroups/$MgtGroup"