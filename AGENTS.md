# Agent Instructions for Azure Infrastructure Provisioning

## Project Overview
This project provisions Azure infrastructure using Bicep templates and Bash scripts. The infrastructure includes:
- Resource Group in denmarkeast
- Virtual Network (10.0.0.0/16) with single subnet
- Network Security Group with ASG-based rules
- Three Ubuntu 24.04 LTS VMs: Web Server, Reverse Proxy, and Bastion Host
- NGINX-based reverse proxy configuration

## Build/Lint/Test Commands

### Shell Script Validation
```bash
# Syntax check
bash -n provisioning.sh

# ShellCheck linting
shellcheck provisioning.sh

# Run provisioning script
./provisioning.sh
```

### Bicep Validation
```bash
# Validate Bicep syntax
az bicep build --file infrastructure.bicep

# Build for inspection
az bicep build --file infrastructure.bicep --stdout
```

### Manual Testing
```bash
# Test reverse proxy connectivity
curl http://<REVERSE_PROXY_IP>

# SSH to bastion host
ssh azureuser@<BASTION_IP>

# SSH to internal VMs via bastion
ssh -o ProxyJump="azureuser@<BASTION_IP>" azureuser@10.0.0.4
```

## Code Style Guidelines

### Bash Scripting

#### Structure & Organization
- Use `set -euo pipefail` at script start for strict error handling
- Define all configuration as `readonly` constants at the top
- Group related constants with blank lines
- Use descriptive function names in snake_case (e.g., `create_resource_group`)
- Each function should handle a single responsibility (SRP)
- Use `log()` and `log_section()` for all output
- Implement retry logic with exponential backoff for Azure API calls

#### Naming Conventions
- Constants: SCREAMING_SNAKE_CASE (e.g., `RESOURCE_GROUP`, `NSG_NAME`)
- Functions: snake_case (e.g., `deploy_infrastructure`)
- Local variables: snake_case (e.g., `nic_name`, `ip_config_name`)
- Use `local` keyword for all function-scoped variables

#### Error Handling
- Always check command exit codes with `set -e`
- Use `wait_for_resource()` for Azure resource provisioning
- Log warnings with `log "Warning: ..."` for non-critical failures
- Implement retry logic with configurable attempts and delays
- Validate required files exist before use

#### Function Design
- Functions should be pure where possible (no side effects)
- Pass parameters explicitly, avoid global state
- Return exit codes: 0 for success, non-zero for failure
- Use arrays for command arguments to handle spaces properly
- Quote all variable expansions: `"${variable}"`

### Bicep Templates

#### Structure
- Use `@description()` for all parameters
- Use `@secure()` for sensitive parameters (SSH keys, passwords)
- Provide sensible defaults for non-sensitive parameters
- Use consistent resource naming: `${name}${suffix}` (e.g., `${vmName}Nic`)
- Group related resources logically with comments
- Use `dependsOn` explicitly when implicit dependencies are unclear

#### Naming Conventions
- Parameters: camelCase (e.g., `adminUsername`, `vnetAddressPrefix`)
- Resources: camelCase (e.g., `reverseProxyAsg`, `webServerVm`)
- Outputs: camelCase (e.g., `reverseProxyPublicIp`)

#### Best Practices
- Use latest stable API versions (e.g., `@2024-03-01`)
- Use Application Security Groups for traffic segmentation
- Associate NSG at subnet level, not individual NICs
- Use `standard` SKU for public IPs
- Disable password authentication on Linux VMs

### Cloud-Init (Shell Script Format)

#### Structure
- Use `#cloud-config` header on first line
- Set `package_update: false` and `package_upgrade: false` to avoid timeouts
- Use 2-space indentation for YAML
- Group packages, write_files, runcmd logically
- Base64 encode in provisioning script before passing to Bicep

#### NGINX Configuration
- Follow standard NGINX config syntax
- Use descriptive server blocks
- Include security headers in reverse proxy configs
- Document port choices in comments

## Architecture Patterns

### Clean Code Principles
- **Single Responsibility**: Each function does one thing
- **Open/Closed**: Extend by adding functions, not modifying existing ones
- **Dependency Inversion**: Depend on abstractions (parameters), not concrete values
- **DRY**: Extract repeated patterns into helper functions

### Infrastructure as Code
- Define all infrastructure as code (no manual portal changes)
- Use constants for all configuration values
- Implement idempotent operations where possible
- Document resource relationships and dependencies

### Security
- Use SSH key authentication (no passwords)
- Web Server has no public IP (internal only)
- Bastion Host for SSH access to internal VMs
- NSG rules follow least privilege principle

## Common Tasks

### Adding a New VM
1. Add VM name parameter to `infrastructure.bicep`
2. Create NIC resource (with or without public IP)
3. Create VM resource with cloud-init if needed
4. Add ASG if new traffic segmentation required
5. Assign ASG to NIC IP configuration
6. Add NSG rules if new ports required

### Modifying Network Security
1. Add security rule to NSG in Bicep with unique priority
2. Priority order: lower numbers = higher priority
3. Use ASGs for destination when possible
4. Default deny, explicit allow rules only

### Debugging
1. Check Azure CLI auth: `az account show`
2. Verify resource group: `az group show --name ${RESOURCE_GROUP}`
3. Check resource state: `az resource show --resource-type ...`
4. Enable verbose logging: add `--debug` to az commands
5. Check deployment outputs: `cat /tmp/deployment_outputs.json`

## Files Reference
- `infrastructure.bicep` - Bicep template for all Azure resources
- `provisioning.sh` - Main deployment script with SSH key handling
- `cloud-init_webserver.sh` - Cloud-init for web server (nginx on 8080)
- `cloud-init_reverseproxy.sh` - Cloud-init for reverse proxy (nginx on 80)
- `dev.bicepparam` - Parameter file (created but not used)

## Environment Variables
No environment variables required. All configuration is in script constants.

## Dependencies
- Azure CLI (az) version 2.0+
- Bicep CLI (az bicep)
- Bash 4.0+
- Cloud-init (on VMs)
- NGINX (on VMs)
