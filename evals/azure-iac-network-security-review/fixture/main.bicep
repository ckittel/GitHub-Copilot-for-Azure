// Minimal sample IaC for the network-security-review eval.
// Intentionally contains network-exposure issues (public blob access,
// no private endpoint, permissive network ACLs) for the review to surface.

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Globally unique storage account name.')
param storageAccountName string = 'st${uniqueString(resourceGroup().id)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: true
    publicNetworkAccess: 'Enabled'
    minimumTlsVersion: 'TLS1_0'
    supportsHttpsTrafficOnly: false
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

output storageAccountId string = storageAccount.id
