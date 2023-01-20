targetScope = 'resourceGroup'

param prefix string
param location string
param tags object

var services = [
  'KeyVault'
  'EventHub'
  'Storage'
]

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: '${prefix}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'internal'
        properties: {
          addressPrefix: '10.0.1.0/24'
          serviceEndpoints: [for service in services: {
            service: 'Microsoft.${service}'
          }]
        }
      }
    ]
  }
  tags: tags
}

