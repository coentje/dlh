targetScope = 'subscription' 

param organization string = 'de-loos'
param project string = 'DataLoosHouse'
param location string = 'WestEurope'
param environment string = 'Development'
param owner string = 'cdeloos@outlook.com'
param version string = '0.0.1'

param organizationAbb string = 'dl'
param projectAbb string = 'dlh'
param locationAbb string = 'we'
param environmentAbb string = 'dev'
// param ownerAbb string = 'cdl'az account sh

param ipExcemptions array = [
  { 
    name: 'Coen @ Home'
    address: '77.171.212.247'
  }
]

var tags = {
  project: project
  environment: environment
  owner: owner
  version: version
}

var prefix = toLower('${organizationAbb}-${projectAbb}-${environmentAbb}-${locationAbb}')

var repoConfig = {
  type: 'FactoryGitHubConfiguration'
  accountName: organization
  repositoryName: project
  collaborationBranch: 'master'
  projectName: project
}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: '${prefix}-rg'
  location: location
  tags: tags  
}

module vnet 'vnet.bicep' = {
  scope: resourceGroup
  name: 'vnet'
  params: {
    location: location
    prefix: prefix
    tags: tags
  }
}

module pur 'purview.bicep' = {
  scope: resourceGroup
  name: 'purview'
  params: {
    location: location
    prefix: prefix
    tags: tags
  }
  dependsOn: [
    vnet
  ]
}

module keyVault 'keyVault.bicep' = {
  scope: resourceGroup
  name: 'keyVault'
  params: {
    ipExcemptions: ipExcemptions
    location: location
    prefix: prefix
    tags: tags
  }
  dependsOn: [
    vnet
    pur
  ]
}

module sa 'storageAccount.bicep' = {
  scope: resourceGroup
  name: 'storageAccount'
  params: {
    ipExcemptions: ipExcemptions
    location: location
    prefix: prefix
    tags: tags
  }
  dependsOn: [
    vnet
    keyVault
    pur
  ]
}

module adf 'adf.bicep' = {
  scope: resourceGroup
  name: 'adf'
  params: {
    location: location
    prefix: prefix
    isDev: environmentAbb == 'dev'
    repoConfig: repoConfig
    tags: tags
  }
  dependsOn: [
    vnet
    pur
  ]
}

module syn 'synapse.bicep' = {
  scope: resourceGroup
  name: 'synapse'
  params: {
    location: location
    prefix: prefix
    isDev: environmentAbb == 'dev'
    repoConfig: repoConfig
    tags: tags
  }
  dependsOn: [
    keyVault
    vnet
    sa
    pur
  ]
}

module evt 'serviceBus.bicep' = {
  scope: resourceGroup
  name: 'serviceBus'
  params: {
    location: location
    prefix: prefix
    tags: tags
    ipExcemptions: ipExcemptions
  }
  dependsOn: [
    vnet
    keyVault
    pur
  ]
}

