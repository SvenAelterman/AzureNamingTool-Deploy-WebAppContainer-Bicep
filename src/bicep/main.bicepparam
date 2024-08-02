using './main.bicep'

param namingConvention = 'AzureNamingTool-demo-{rtype}-${location}-{seq}'
param location = 'canadacentral'
param sequence = 1
param tags = {
  'date-created': '2024-08-02'
}

param networkAddressPrefix = '10.0.3.0/24'
param userOrGroupPrincipalId = '861bff28-2d07-4861-a058-cfbe5e7f04ed'
