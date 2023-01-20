targetScope = 'resourceGroup'

param prefix string
param location string
param tags object
param ipExcemptions array

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: '${prefix}-vnet'
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: 'internal'
  parent: vnet
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: '${prefix}-kv'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    enableRbacAuthorization: true
    enableSoftDelete: true
    provisioningState: 'Succeeded'
    createMode: 'default'
    publicNetworkAccess: 'disabled'    
    softDeleteRetentionInDays: 30
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [ for ip in ipExcemptions: {
        value: ip.address
      }]
      virtualNetworkRules: [
        {
          id: subnet.id
        }
      ]
    }
  }
  tags: tags
}

resource keyVaultAccountEndpoint 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  name: '${prefix}-kv-pe'
  location: location
  properties: {
    subnet: subnet
    privateLinkServiceConnections: [
      {
        name: '${prefix}-kv-pe'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [ 
            'vault'
          ]
        }
      }
    ]
  }
  tags: tags
}

