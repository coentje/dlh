targetScope = 'resourceGroup'

param prefix string
param tags object
param ipExcemptions array
param location string = resourceGroup().location

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: '${prefix}-vnet'
}
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: 'internal'
  parent: vnet
}

resource serviceBus 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' = {
  name: '${prefix}-sb'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    disableLocalAuth: true
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
  }
  tags: tags
}

resource sbNetworkRules 'Microsoft.ServiceBus/namespaces/networkRuleSets@2022-01-01-preview' = {
  name: 'default'
  parent: serviceBus
  properties: {
    defaultAction: 'Deny'
    publicNetworkAccess: 'Disabled'
    trustedServiceAccessEnabled: true
    virtualNetworkRules: [
      {
        ignoreMissingVnetServiceEndpoint: true
        subnet: subnet
      }
    ]
    ipRules: [for ip in ipExcemptions: {
        action: 'Allow'
        ipMask: ip.address
      }]
  }
}

resource serviceBusEndpoint 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  name: '${prefix}-sb-pe'
  location: location
  properties: {
    subnet: subnet
    privateLinkServiceConnections: [
      serviceBus
    ]
  }
  tags: tags
}
