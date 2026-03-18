{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location": {
      "value": "denmarkeast"
    },
    "adminPublicKey": {
      "value": ""
    },
    "webServerCloudInit": {
      "value": "[loadTextContent('./cloud-init_webserver.sh')]"
    },
    "reverseProxyCloudInit": {
      "value": "[loadTextContent('./cloud-init_reverseproxy.sh')]"
    }
  }
}
