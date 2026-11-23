## Purpose
-   Deploys FunctionApp that that takes teh current Azure Reservation ISF Ratios and puts them into a CSV artifact
    -   artifact will be used in a different script to rationalize reservation purchases for customers.

## Deploy the Function App initially 
-   init-deploy.ps1

## Linux Runtime requires PowerShell Modules in the deployment
-   one time run - scripts\ApplyModules.ps1 (run from the prject root)

## Set the Permissions before Deployment
-   Set-Permissions.ps1


## Create the zip package and Deploy Code
-   Appdeployment-zip.ps1
-   initial deployment or code updates use same code






