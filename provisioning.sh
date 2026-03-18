#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_NAME="Azure Infrastructure Provisioning"
readonly RESOURCE_GROUP="DemoRG"
readonly LOCATION="denmarkeast"
readonly BICEP_FILE="infrastructure.bicep"

readonly VM_IMAGE="Ubuntu2404"
readonly VM_SIZE="Standard_B1ls"
readonly ADMIN_USERNAME="azureuser"
readonly SSH_KEY_FILE="${HOME}/.ssh/id_rsa.pub"

readonly WEB_SERVER_NAME="WebServer"
readonly REVERSE_PROXY_NAME="ReverseProxy"
readonly BASTION_HOST_NAME="BastionHost"

readonly BICEP_PARAM_FILE="dev.bicepparam"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CLOUD_INIT_WEBSERVER="${SCRIPT_DIR}/cloud-init_webserver.sh"
readonly CLOUD_INIT_REVERSEPROXY="${SCRIPT_DIR}/cloud-init_reverseproxy.sh"

readonly MAX_RETRY_ATTEMPTS=30
readonly RETRY_DELAY_SECONDS=2

log() {
  echo "[INFO] $1"
}

log_section() {
  echo ""
  echo "========================================"
  echo "[SECTION] $1"
  echo "========================================"
  echo ""
}

wait_for_resource() {
  local resource_type="$1"
  local resource_name="$2"
  local query="$3"

  log "Waiting for ${resource_type} '${resource_name}' to be available..."

  local attempt=0

  while [[ ${attempt} -lt ${MAX_RETRY_ATTEMPTS} ]]; do
    attempt=$((attempt + 1))

    if az resource show \
      --resource-group "${RESOURCE_GROUP}" \
      --resource-type "${resource_type}" \
      --name "${resource_name}" \
      --query "${query}" \
      --output tsv > /dev/null 2>&1; then
      log "${resource_type} '${resource_name}' is ready"
      return 0
    fi

    log "Attempt ${attempt}/${MAX_RETRY_ATTEMPTS}: Resource not ready yet, waiting ${RETRY_DELAY_SECONDS}s..."
    sleep "${RETRY_DELAY_SECONDS}"
  done

  log "Error: ${resource_type} '${resource_name}' did not become available within ${MAX_RETRY_ATTEMPTS} attempts"
  return 1
}

create_resource_group() {
  log "Creating resource group: ${RESOURCE_GROUP}"

  az group create \
    --name "${RESOURCE_GROUP}" \
    --location "${LOCATION}"
}

validate_bicep_file() {
  log "Validating Bicep file: ${BICEP_FILE}"

  if [[ ! -f "${SCRIPT_DIR}/${BICEP_FILE}" ]]; then
    log "Error: Bicep file '${BICEP_FILE}' not found"
    return 1
  fi

  if ! az bicep build --file "${SCRIPT_DIR}/${BICEP_FILE}" > /dev/null 2>&1; then
    log "Error: Bicep file validation failed"
    return 1
  fi

  log "Bicep file validation successful"
}

get_or_generate_ssh_key() {
  if [[ "${1:-}" == "--quiet" ]]; then
    if [[ ! -f "${SSH_KEY_FILE}" ]]; then
      mkdir -p "${HOME}/.ssh"
      ssh-keygen -t rsa -b 4096 -f "${HOME}/.ssh/id_rsa" -N "" -q 2>/dev/null
    fi
    tr -d '\r\n' < "${SSH_KEY_FILE}"
    return
  fi

  log_section "SSH Key Setup"

  if [[ -f "${SSH_KEY_FILE}" ]]; then
    log "Found existing SSH public key: ${SSH_KEY_FILE}"
  else
    log "No SSH key found, generating new key pair..."
    mkdir -p "${HOME}/.ssh"
    ssh-keygen -t rsa -b 4096 -f "${HOME}/.ssh/id_rsa" -N "" -q
    log "Generated new SSH key pair"
  fi

  local ssh_key
  ssh_key=$(tr -d '\r\n' < "${SSH_KEY_FILE}")
  
  log "SSH key length: ${#ssh_key} characters"
  log "SSH key preview: ${ssh_key:0:50}..."
  
  echo "${ssh_key}"
}

deploy_infrastructure() {
  log_section "Deploying Infrastructure with Bicep"

  get_or_generate_ssh_key

  local admin_public_key
  admin_public_key=$(get_or_generate_ssh_key --quiet)

  local web_server_cloud_init
  web_server_cloud_init=$(base64 -w0 < "${CLOUD_INIT_WEBSERVER}")

  local reverse_proxy_cloud_init
  reverse_proxy_cloud_init=$(base64 -w0 < "${CLOUD_INIT_REVERSEPROXY}")

  log "Deploying Bicep template to resource group: ${RESOURCE_GROUP}"

  local params_file
  params_file=$(mktemp)

  cat > "${params_file}" << EOF
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location": {
      "value": "${LOCATION}"
    },
    "adminPublicKey": {
      "value": "${admin_public_key}"
    },
    "webServerCloudInit": {
      "value": "${web_server_cloud_init}"
    },
    "reverseProxyCloudInit": {
      "value": "${reverse_proxy_cloud_init}"
    }
  }
}
EOF

 az deployment group create \
    --resource-group "${RESOURCE_GROUP}" \
    --template-file "${SCRIPT_DIR}/${BICEP_FILE}" \
    --parameters "@${params_file}" \
    --query 'properties.outputs' \
    --output json > /tmp/deployment_outputs.json

  rm -f "${params_file}"

  log "Infrastructure deployment completed"
}


get_vm_public_ip() {
  local vm_name="$1"

  az vm show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${vm_name}" \
    --show-details \
    --query 'publicIps' \
    --output tsv
}

display_vm_list() {
  log_section "Virtual Machine List"

  az vm list \
    --resource-group "${RESOURCE_GROUP}" \
    --output table
}

display_connection_info() {
  log_section "Connection Information"

  local reverse_proxy_ip
  reverse_proxy_ip=$(get_vm_public_ip "${REVERSE_PROXY_NAME}")
  echo "Reverse Proxy IP: ${reverse_proxy_ip}"

  local bastion_host_ip
  bastion_host_ip=$(get_vm_public_ip "${BASTION_HOST_NAME}")
  echo "Bastion Host IP: ${bastion_host_ip}"
}

test_reverse_proxy() {
  log_section "Testing Reverse Proxy"

  local reverse_proxy_ip
  reverse_proxy_ip=$(get_vm_public_ip "${REVERSE_PROXY_NAME}")

  if [[ -n "${reverse_proxy_ip}" ]]; then
    log "Testing HTTP connection to reverse proxy"
    curl --fail --silent --max-time 10 "http://${reverse_proxy_ip}" || \
      log "Warning: Reverse proxy not responding yet"
  else
    log "Warning: Reverse proxy IP not available"
  fi
}

main() {
  log_section "${SCRIPT_NAME}"

  create_resource_group
  validate_bicep_file
  deploy_infrastructure
  display_vm_list
  display_connection_info
  test_reverse_proxy

  log_section "Provisioning Complete"
}

main "$@"
