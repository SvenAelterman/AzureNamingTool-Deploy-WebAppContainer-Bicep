targetScope = 'subscription'

param namingConvention string = 'AzureNamingTool-demo-{rtype}-${location}-{seq}'
param location string
param sequence int = 1
param tags object = {}
param containerImage string = 'azurenamingtool'

param networkAddressPrefix string

param userOrGroupPrincipalId string

var sequenceFormatted = format('{0:00}', sequence)
var namingStructure = replace(namingConvention, '{seq}', sequenceFormatted)
var resourceGroupName = replace(namingStructure, '{rtype}', 'rg')

module resourceGroupModule 'br/public:avm/res/resources/resource-group:0.2.4' = {
  name: 'AzureNamingTool-resourceGroup'
  params: {
    // Required parameters
    name: resourceGroupName

    // Non-required parameters
    location: location
    lock: {
      kind: 'CanNotDelete'
      name: 'lock-${resourceGroupName}'
    }
    tags: tags
  }
}
module networkSecurityGroupModule 'br/public:avm/res/network/network-security-group:0.3.1' = {
  name: 'networkSecurityGroupDeployment'
  scope: resourceGroup(resourceGroupName)
  params: {
    // Required parameters
    name: replace(namingStructure, '{rtype}', 'nsg')

    // Non-required parameters
    location: location
    securityRules: []
    tags: tags
  }
  dependsOn: [resourceGroupModule]
}

module virtualNetworkModule 'br/public:avm/res/network/virtual-network:0.1.8' = {
  name: 'AzureNamingTool-virtualNetwork'
  scope: resourceGroup(resourceGroupName)
  params: {
    // Required parameters
    addressPrefixes: [
      networkAddressPrefix
    ]
    name: replace(namingStructure, '{rtype}', 'vnet')

    // Non-required parameters
    location: location
    subnets: [
      {
        addressPrefix: cidrSubnet(networkAddressPrefix, 26, 0)
        name: 'ApplicationSubnet'
        networkSecurityGroupResourceId: networkSecurityGroupModule.outputs.resourceId
        serviceEndpoints: [
          {
            service: 'Microsoft.Storage'
          }
        ]
        delegations: [
          {
            name: 'serverfarmDelegation'
            properties: {
              serviceName: 'Microsoft.Web/serverFarms'
            }
          }
        ]
      }
    ]
    tags: tags
  }
}

module userAssignedIdentityModule 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.2' = {
  name: 'AzureNamingTool-userAssignedIdentity'
  scope: resourceGroup(resourceGroupName)
  params: {
    // Required parameters
    name: replace(namingStructure, '{rtype}', 'id')

    // Non-required parameters
    location: location
    tags: tags
  }

  dependsOn: [resourceGroupModule]
}

module registryModule 'br/public:avm/res/container-registry/registry:0.3.2' = {
  name: 'AzureNamingTool-registry'
  scope: resourceGroup(resourceGroupName)
  params: {
    // Required parameters
    name: toLower(replace(replace(namingStructure, '{rtype}', 'cr'), '-', ''))

    // Non-required parameters
    acrAdminUserEnabled: false
    acrSku: 'Basic'
    azureADAuthenticationAsArmPolicyStatus: 'enabled'
    exportPolicyStatus: 'enabled'
    location: location
    quarantinePolicyStatus: 'enabled'
    softDeletePolicyDays: 7
    softDeletePolicyStatus: 'disabled'
    tags: tags
    trustPolicyStatus: 'enabled'

    roleAssignments: [
      {
        principalId: userAssignedIdentityModule.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'AcrPull'
      }
      {
        principalId: userOrGroupPrincipalId
        roleDefinitionIdOrName: 'AcrPush'
      }
    ]
  }
}

module serverfarmModule 'br/public:avm/res/web/serverfarm:0.2.2' = {
  name: 'AzureNamingTool-serverfarm'
  scope: resourceGroup(resourceGroupName)
  params: {
    // Required parameters
    name: replace(namingStructure, '{rtype}', 'plan')
    skuCapacity: 1
    skuName: 'P0v3'

    kind: 'Linux'
    location: location
    tags: tags
    zoneRedundant: false
  }

  dependsOn: [resourceGroupModule]
}

module siteModule 'br/public:avm/res/web/site:0.3.9' = {
  name: 'AzureNamingTool-site'
  scope: resourceGroup(resourceGroupName)
  params: {
    // Required parameters
    kind: 'app,linux,container'
    name: replace(namingStructure, '{rtype}', 'app')
    serverFarmResourceId: serverfarmModule.outputs.resourceId

    // Non-required parameters
    basicPublishingCredentialsPolicies: [
      {
        allow: false
        name: 'ftp'
      }
      {
        allow: false
        name: 'scm'
      }
    ]

    httpsOnly: true
    location: location

    managedIdentities: {
      systemAssigned: true
      userAssignedResourceIds: [
        userAssignedIdentityModule.outputs.resourceId
      ]
    }
    publicNetworkAccess: 'Enabled'
    scmSiteAlsoStopped: true
    siteConfig: {
      alwaysOn: true

      linuxFxVersion: 'DOCKER|${registryModule.outputs.loginServer}/${containerImage}'
      acrUseManagedIdentityCreds: true
      acrUserManagedIdentityId: userAssignedIdentityModule.outputs.clientId

      metadata: [
        {
          name: 'CURRENT_STACK'
          value: 'dotnetcore'
        }
      ]
    }

    tags: tags

    // storageAccountResourceId: '<storageAccountResourceId>'
    // storageAccountUseIdentityAuthentication: true

    virtualNetworkSubnetId: virtualNetworkModule.outputs.subnetResourceIds[0]
    vnetContentShareEnabled: true
    vnetImagePullEnabled: true
    vnetRouteAllEnabled: true
  }
}

module storageAccount 'br/public:avm/res/storage/storage-account:0.9.1' = {
  name: 'AzureNamingTool-storageAccount'
  scope: resourceGroup(resourceGroupName)
  params: {
    // Required parameters
    // TODO: Use naming tool
    name: 'antdemostcnc01'

    // Non-required parameters
    allowBlobPublicAccess: false
    fileServices: {
      shares: [
        {
          accessTier: 'Hot'
          name: 'azurenamingtool'
          shareQuota: 5120
        }
      ]
      roleAssignments: [
        {
          principalId: userAssignedIdentityModule.outputs.principalId
          roleDefinitionIdOrName: 'Storage File Data SMB Share Contributor'
          principalType: 'ServicePrincipal'
        }
        {
          principalId: userOrGroupPrincipalId
          roleDefinitionIdOrName: 'Storage File Data SMB Share Contributor'
        }
      ]
    }
    largeFileSharesState: 'Enabled'
    location: location
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [
        {
          action: 'Allow'
          value: '69.130.149.21'
        }
      ]
      virtualNetworkRules: [
        {
          action: 'Allow'
          id: virtualNetworkModule.outputs.subnetResourceIds[0]
        }
      ]
    }
    requireInfrastructureEncryption: true
    skuName: 'Standard_ZRS'
    tags: tags
  }

  dependsOn: [resourceGroupModule]
}
