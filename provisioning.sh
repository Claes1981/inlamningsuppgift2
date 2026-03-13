#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_NAME="Azure Infrastructure Provisioning"
readonly RESOURCE_GROUP="DemoRG"
readonly LOCATION="denmarkeast"
readonly BICEP_FILE="infrastructure.bicep"

readonly VM_IMAGE="Ubuntu2204"
readonly VM_SIZE="Standard_B1ls"
readonly ADMIN_USERNAME="azureuser"

readonly WEB_SERVER_NAME="WebServer"
readonly REVERSE_PROXY_NAME="ReverseProxy"
readonly BASTION_HOST_NAME="BastionHost"

readonly WEB_SERVER_CONFIG="web_server_config.yaml"
readonly REVERSE_PROXY_CONFIG="reverse_proxy_config.yaml"

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

  if [[ ! -f "${BICEP_FILE}" ]]; then
    log "Error: Bicep file '${BICEP_FILE}' not found"
    return 1
  fi

  if ! az bicep build --file "${BICEP_FILE}" > /dev/null 2>&1; then
    log "Error: Bicep file validation failed"
    return 1
  fi

  log "Bicep file validation successful"
}

deploy_infrastructure() {
  log_section "Deploying Infrastructure with Bicep"

  log "Deploying Bicep template to resource group: ${RESOURCE_GROUP}"

  az deployment group create \
    --resource-group "${RESOURCE_GROUP}" \
    --template-file "${BICEP_FILE}" \
    --parameters "location=${LOCATION}" \
    --query 'properties.outputs' \
    --output json > /tmp/deployment_outputs.json

  log "Infrastructure deployment completed"
}

apply_cloud_init_configurations() {
  log_section "Applying Cloud-Init Configurations"

  if [[ -f "${WEB_SERVER_CONFIG}" ]]; then
    log "Applying cloud-init configuration to web server"

    az vm run-command invoke \
      --resource-group "${RESOURCE_GROUP}" \
      --name "${WEB_SERVER_NAME}" \
      --command-id RunShellScript \
      --scripts "$(cat "${WEB_SERVER_CONFIG}" | base64 -w0)"
  fi

  if [[ -f "${REVERSE_PROXY_CONFIG}" ]]; then
    log "Applying cloud-init configuration to reverse proxy"

    az vm run-command invoke \
      --resource-group "${RESOURCE_GROUP}" \
      --name "${REVERSE_PROXY_NAME}" \
      --command-id RunShellScript \
      --scripts "$(cat "${REVERSE_PROXY_CONFIG}" | base64 -w0)"
  fi
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
  apply_cloud_init_configurations
  display_vm_list
  display_connection_info
  test_reverse_proxy

  log_section "Provisioning Complete"
}

main "$@"
