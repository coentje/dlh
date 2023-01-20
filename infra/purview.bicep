targetScope = 'resourceGroup'

param prefix string
param location string
param tags object

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: '${prefix}-vnet'
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: 'internal'
  parent: vnet
}

resource purView 'Microsoft.Purview/accounts@2021-07-01' = {
  name: '${prefix}-pur'
  identity: {
     type: 'SystemAssigned'
  }
  location: location
  properties: {
    managedResourceGroupName: '${prefix}-pur-mngd-rg'
    publicNetworkAccess: 'Disabled'
  } 
  tags: tags
}

resource purviewEndpoint 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  name: '${prefix}-pur-pe'
  location: location
  properties: {
    subnet: subnet
    privateLinkServiceConnections: [
      purView
    ]
  }
  tags: tags
}
