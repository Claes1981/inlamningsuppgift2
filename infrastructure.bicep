@description('Resource group location')
param location string = 'denmarkeast'

@description('Virtual network name')
param vnetName string = 'DemoVNet'

@description('Virtual network address prefix')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Subnet name')
param subnetName string = 'default'

@description('Subnet address prefix')
param subnetPrefix string = '10.0.0.0/24'

@description('Network security group name')
param nsgName string = 'DemoNSG'

@description('Reverse proxy application security group name')
param reverseProxyAsgName string = 'ReverseProxyASG'

@description('Bastion host application security group name')
param bastionHostAsgName string = 'BastionHostASG'

@description('VM size')
param vmSize string = 'Standard_B1ls'

@description('Admin username for VMs')
param adminUsername string = 'azureuser'

@description('Web server VM name')
param webServerName string = 'WebServer'

@description('Reverse proxy VM name')
param reverseProxyName string = 'ReverseProxy'

@description('Bastion host VM name')
param bastionHostName string = 'BastionHost'

// Application Security Groups
resource reverseProxyAsg 'Microsoft.Network/applicationSecurityGroups@2024-03-01' = {
  name: reverseProxyAsgName
  location: location
  tags: {
    name: reverseProxyAsgName
  }
}

resource bastionHostAsg 'Microsoft.Network/applicationSecurityGroups@2024-03-01' = {
  name: bastionHostAsgName
  location: location
  tags: {
    name: bastionHostAsgName
  }
}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2024-03-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
        }
      }
    ]
  }
}

// Network Security Group
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-03-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
        properties: {
          priority: 1000
          access: 'Allow'
          protocol: 'Tcp'
          direction: 'Inbound'
          sourceAddressPrefixes: [
            'Internet'
          ]
          sourcePortRanges: [
            '*'
          ]
          destinationAddressPrefixes: [
            '*'
          ]
          destinationPortRanges: [
            '22'
          ]
          destinationApplicationSecurityGroups: [
            bastionHostAsg
          ]
        }
      }
      {
        name: 'AllowHTTP'
        properties: {
          priority: 2000
          access: 'Allow'
          protocol: 'Tcp'
          direction: 'Inbound'
          sourceAddressPrefixes: [
            'Internet'
          ]
          sourcePortRanges: [
            '*'
          ]
          destinationAddressPrefixes: [
            '*'
          ]
          destinationPortRanges: [
            '80'
          ]
          destinationApplicationSecurityGroups: [
            reverseProxyAsg
          ]
        }
      }
    ]
  }
}

// Associate NSG with subnet
resource subnetNsgAssociation 'Microsoft.Network/virtualNetworks/subnets@2024-03-01' = {
  parent: vnet
  name: subnetName
  properties: {
    addressPrefix: subnetPrefix
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

// Web Server Public IP
resource webServerPublicIp 'Microsoft.Network/publicIPAddresses@2024-03-01' = {
  name: '${webServerName}PublicIP'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

// Reverse Proxy Public IP
resource reverseProxyPublicIp 'Microsoft.Network/publicIPAddresses@2024-03-01' = {
  name: '${reverseProxyName}PublicIP'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

// Bastion Host Public IP
resource bastionHostPublicIp 'Microsoft.Network/publicIPAddresses@2024-03-01' = {
  name: '${bastionHostName}PublicIP'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

// Web Server NIC
resource webServerNic 'Microsoft.Network/networkInterfaces@2024-03-01' = {
  name: '${webServerName}Nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnet.id}/subnets/${subnetName}'
          }
          publicIPAddress: {
            id: webServerPublicIp.id
          }
        }
      }
    ]
  }
}

// Reverse Proxy NIC with ASG
resource reverseProxyNic 'Microsoft.Network/networkInterfaces@2024-03-01' = {
  name: '${reverseProxyName}Nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnet.id}/subnets/${subnetName}'
          }
          publicIPAddress: {
            id: reverseProxyPublicIp.id
          }
          applicationSecurityGroups: [
            reverseProxyAsg
          ]
        }
      }
    ]
  }
}

// Bastion Host NIC with ASG
resource bastionHostNic 'Microsoft.Network/networkInterfaces@2024-03-01' = {
  name: '${bastionHostName}Nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnet.id}/subnets/${subnetName}'
          }
          publicIPAddress: {
            id: bastionHostPublicIp.id
          }
          applicationSecurityGroups: [
            bastionHostAsg
          ]
        }
      }
    ]
  }
}

// Web Server VM
resource webServerVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: webServerName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: replace(webServerName, '-', '')
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: ''
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: webServerNic.id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

// Reverse Proxy VM
resource reverseProxyVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: reverseProxyName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: replace(reverseProxyName, '-', '')
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: ''
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: reverseProxyNic.id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

// Bastion Host VM
resource bastionHostVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: bastionHostName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: replace(bastionHostName, '-', '')
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: ''
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: bastionHostNic.id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

// Outputs
output webServerPublicIp string = webServerPublicIp.properties.ipAddress
output reverseProxyPublicIp string = reverseProxyPublicIp.properties.ipAddress
output bastionHostPublicIp string = bastionHostPublicIp.properties.ipAddress
