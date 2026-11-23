# --- Configuration Details ---
$configPath = Join-Path $PSScriptRoot "Config\Config.psd1"
$config = Import-PowerShellDataFile -Path $configPath

$FunctionAppName = $config.FunctionAppName
$FunctionName = $config.FunctionName
$uriFunctionAppName = $config.FunctionAppName.toLower()

Write-Host "Fetching Master Host Key to bypass security headers..."
$MasterKey = az functionapp keys list --resource-group $config.ResourceGroup --name $config.FunctionAppName --query "masterKey" -o tsv

# Non-HTTP triggers are invoked by hitting the administrative /admin/functions endpoint
$Uri = "https://$FunctionAppName.azurewebsites.net/admin/functions/$FunctionName"

Write-host $Uri

$Headers = @{
    "x-functions-key" = $MasterKey
}

# The endpoint expects an application/json Content-Type and an empty JSON payload body
$Body = "{}" 

Write-Host "Manually executing timer trigger via API request..."
$Response = Invoke-RestMethod -Uri $Uri -Method Post -Headers $Headers -ContentType "application/json" -Body $Body

if ($Response.StatusCode -eq 202 -or $lastExitCode -eq 0) {
    Write-Host "Success! Check your Storage Account 'function-outputs' container for the new file." -ForegroundColor Green
} else {
    Write-Host "Invocation completed."
}
