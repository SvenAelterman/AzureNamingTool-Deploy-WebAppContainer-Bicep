[CmdletBinding()]
Param(
    [Parameter(Position = 1, Mandatory)]
    [string]$ContainerRegistryLoginServer,
    [Parameter(Mandatory, Position = 2)]
    [string]$ImageName
)

# Download the latest release ZIP of the Azure Naming Tool from GitHub

# Extract the ZIP file

# Run the build tool

# Push the container to the registry