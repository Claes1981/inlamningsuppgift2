# Agent Instructions for Azure Infrastructure Provisioning

## Project Overview
This project provisions a .NET web application infrastructure to Azure using Bash scripts and cloud-init configurations. The infrastructure includes:
- Resource Group in denmarkeast
- Virtual Network (10.0.0.0/16)
- Network Security Group with custom rules
- Application Security Groups for traffic segmentation
- Three Ubuntu VMs: Web Server, Reverse Proxy, and Bastion Host
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

### Cloud-Config Validation
```bash
# Validate cloud-config syntax
cloud-config-validate reverse_proxy_config.yaml
cloud-config-validate web_server_config.yaml
```

### Manual Testing
```bash
# Test reverse proxy connectivity
curl http://<REVERSE_PROXY_IP>

# SSH to bastion host
ssh azureuser@<BASTION_IP>
```

## Code Style Guidelines

### Bash Scripting

#### Structure & Organization
- Use `set -euo pipefail` at script start for strict error handling
- Define all configuration as `readonly` constants at the top
- Group related constants with blank lines
- Use descriptive function names in snake_case (e.g., `create_network_security_group`)
- Each function should handle a single responsibility (SRP)
- Use `log()` and `log_section()` for all output
- Implement retry logic with exponential backoff for Azure API calls

#### Naming Conventions
- Constants: SCREAMING_SNAKE_CASE (e.g., `RESOURCE_GROUP`, `NSG_NAME`)
- Functions: snake_case (e.g., `create_virtual_machine`)
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

### YAML (Cloud-Config)

#### Structure
- Use `#cloud-config` header on first line
- Follow canonical cloud-init format
- Use 2-space indentation
- Group packages, write_files, runcmd logically

#### NGINX Configuration
- Follow standard NGINX config syntax
- Use descriptive server blocks
- Include security headers in reverse proxy configs
- Document port choices in comments

### Azure CLI Commands

#### Best Practices
- Always specify `--resource-group` explicitly
- Use `--output tsv` for scripting, `--output table` for display
- Quote values: `--name "${RESOURCE_GROUP}"`
- Use `--query` for extracting specific fields
- Implement polling for long-running operations

#### Resource Management
- Use Application Security Groups for traffic segmentation
- Associate NSG at subnet level, not individual NICs
- Wait for resource provisioning state before dependent operations
- Clean up resources in reverse creation order

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

## Common Tasks

### Adding a New VM
1. Add VM constant names (NAME, CONFIG if needed)
2. Call `create_virtual_machine()` in `create_virtual_machines()`
3. Create ASG if needed
4. Assign ASG to VM NIC in `assign_application_security_groups()`
5. Add NSG rules if new ports required

### Modifying Network Security
1. Add `create_nsg_rule()` call with unique priority
2. Priority order: lower numbers = higher priority
3. Use ASGs for destination, not IP addresses
4. Default deny, explicit allow rules only

### Debugging
1. Check Azure CLI auth: `az account show`
2. Verify resource group: `az group show --name ${RESOURCE_GROUP}`
3. Check resource state: `az resource show --resource-type ...`
4. Enable verbose logging: add `--debug` to az commands

## Files Reference
- `provisioning.sh` - Main Azure infrastructure provisioning script
- `reverse_proxy_config.yaml` - Cloud-init config for reverse proxy VM
- `web_server_config.yaml` - Cloud-init config for web server VM
- `.gitignore` - Git ignore patterns for Azure/.NET projects

## Environment Variables
No environment variables required. All configuration is in script constants.

## Dependencies
- Azure CLI (az) version 2.0+
- Bash 4.0+
- Cloud-init (on VMs)
- NGINX (on VMs)
