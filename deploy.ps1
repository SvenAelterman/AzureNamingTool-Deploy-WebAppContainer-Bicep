<#
.SYNOPSIS
    Performs a deployment of Azure resources to support running the Azure Naming Tool.

.DESCRIPTION
    Use this for manual deployments only.
    If using a CI/CD pipeline, specify the necessary parameters in the pipeline definition.

.PARAMETER TemplateParameterFile
    The path to the template parameter file in bicepparam format.

.PARAMETER TargetSubscriptionId
    The subscription ID to deploy the resources to. The subscription must already exist.

.PARAMETER Location
    The Azure region to deploy the resources to.

.EXAMPLE
    ./deploy.ps1 -TemplateParameterFile '.\main.bicepparam' -TargetSubscriptionId '00000000-0000-0000-0000-000000000000' -Location 'eastus' 

.EXAMPLE
    ./deploy.ps1 '.\main.prj.bicepparam' '00000000-0000-0000-0000-000000000000' 'eastus'
#>

#Requires -Modules "Az.Resources"
#Requires -PSEdition Core

[CmdletBinding()]
Param(
    [Parameter()]
    [string]$TemplateParameterFile = './src/bicep/main.bicepparam',
    [Parameter(Mandatory)]
    [string]$TargetSubscriptionId,
    [Parameter(Mandatory)]
    [string]$Location,
    [Parameter()]
    [string]$Environment = 'AzureCloud'
)

# Define common parameters for the New-AzDeployment cmdlet
[hashtable]$CmdLetParameters = @{
    TemplateFile = './src/bicep/main.bicep'
    Location     = $Location
}

if ($TemplateParameterFile) {
    $CmdLetParameters.Add('TemplateParameterFile', $TemplateParameterFile)
}

# Generate a unique name for the deployment
[string]$DeploymentName = "AzureNamingTool-$(Get-Date -Format 'yyyyMMddThhmmssZ' -AsUTC)"
$CmdLetParameters.Add('Name', $DeploymentName)

# Execute the deployment
$DeploymentResult = New-AzDeployment @CmdLetParameters

# Evaluate the deployment results
if ($DeploymentResult.ProvisioningState -eq 'Succeeded') {
    Write-Host "🔥 Deployment succeeded."

    $DeploymentResult.Outputs | Format-Table -Property @{Name = 'Output Name'; Expression = { $_.Key } }, @{Name = 'Value'; Expression = { $_.Value.Value } }
}
else {
    $DeploymentResult
}
