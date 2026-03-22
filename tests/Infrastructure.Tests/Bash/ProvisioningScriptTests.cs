using Xunit;
using FluentAssertions;
using System.IO;

namespace Infrastructure.Tests.Bash;

public class ProvisioningScriptTests
{
    private readonly string _testDataPath;

    public ProvisioningScriptTests()
    {
        var assemblyPath = Directory.GetCurrentDirectory();
        while (!Directory.Exists(Path.Combine(assemblyPath, "infra")))
        {
            assemblyPath = Directory.GetParent(assemblyPath)?.FullName ?? assemblyPath;
            if (assemblyPath == null)
            {
                throw new FileNotFoundException("Could not find infra directory");
            }
        }
        _testDataPath = Path.Combine(assemblyPath, "infra");
    }

    [Fact]
    public void ProvisioningScript_Exists()
    {
        // Arrange
        var scriptPath = Path.Combine(_testDataPath, "provisioning.sh");

        // Act & Assert
        File.Exists(scriptPath).Should().BeTrue("Provisioning script should exist");
    }

    [Fact]
    public void ProvisioningScript_HasShebang()
    {
        // Arrange
        var scriptPath = Path.Combine(_testDataPath, "provisioning.sh");
        var content = File.ReadAllText(scriptPath);

        // Act & Assert
        content.Should().StartWith("#!/usr/bin/env bash", "Script should have proper shebang");
    }

    [Fact]
    public void ProvisioningScript_UsesStrictMode()
    {
        // Arrange
        var scriptPath = Path.Combine(_testDataPath, "provisioning.sh");
        var content = File.ReadAllText(scriptPath);

        // Act & Assert
        content.Should().Contain("set -euo pipefail", "Script should use strict error handling");
    }

    [Fact]
    public void ProvisioningScript_DefinesConstants()
    {
        // Arrange
        var scriptPath = Path.Combine(_testDataPath, "provisioning.sh");
        var content = File.ReadAllText(scriptPath);

        // Act & Assert
        content.Should().Contain("readonly", "Script should use readonly constants");
        content.Should().Contain("RESOURCE_GROUP", "Should define resource group constant");
        content.Should().Contain("LOCATION", "Should define location constant");
    }

    [Fact]
    public void ProvisioningScript_HasLoggingFunctions()
    {
        // Arrange
        var scriptPath = Path.Combine(_testDataPath, "provisioning.sh");
        var content = File.ReadAllText(scriptPath);

        // Act & Assert
        content.Should().Contain("log()", "Should have log function");
        content.Should().Contain("log_error()", "Should have log_error function");
        content.Should().Contain("log_section()", "Should have log_section function");
    }

    [Fact]
    public void ProvisioningScript_HasValidationFunctions()
    {
        // Arrange
        var scriptPath = Path.Combine(_testDataPath, "provisioning.sh");
        var content = File.ReadAllText(scriptPath);

        // Act & Assert
        content.Should().Contain("validate_prerequisites", "Should validate prerequisites");
        content.Should().Contain("validate_bicep_file", "Should validate Bicep file");
        content.Should().Contain("validate_cloud_init_files", "Should validate cloud-init files");
    }

    [Fact]
    public void ProvisioningScript_HasSSHKeyManagement()
    {
        // Arrange
        var scriptPath = Path.Combine(_testDataPath, "provisioning.sh");
        var content = File.ReadAllText(scriptPath);

        // Act & Assert
        content.Should().Contain("ensure_ssh_key", "Should have SSH key management");
        content.Should().Contain("generate_ssh_key", "Should be able to generate SSH keys");
        content.Should().Contain("ssh-keygen", "Should use ssh-keygen for key generation");
    }

    [Fact]
    public void ProvisioningScript_HasAzureResourceFunctions()
    {
        // Arrange
        var scriptPath = Path.Combine(_testDataPath, "provisioning.sh");
        var content = File.ReadAllText(scriptPath);

        // Act & Assert
        content.Should().Contain("create_resource_group", "Should create resource group");
        content.Should().Contain("provision_infrastructure", "Should provision infrastructure");
        content.Should().Contain("az deployment group create", "Should use Azure CLI for Resource Group creation.");
    }

    [Fact]
    public void ProvisioningScript_HasRetryLogic()
    {
        // Arrange
        var scriptPath = Path.Combine(_testDataPath, "provisioning.sh");
        var content = File.ReadAllText(scriptPath);

        // Act & Assert
        content.Should().Contain("wait_for_resource", "Should have retry logic for resources");
        content.Should().Contain("MAX_RETRY_ATTEMPTS", "Should define max retry attempts");
    }

    [Fact]
    public void ProvisioningScript_HasMainFunction()
    {
        // Arrange
        var scriptPath = Path.Combine(_testDataPath, "provisioning.sh");
        var content = File.ReadAllText(scriptPath);

        // Act & Assert
        content.Should().Contain("main()", "Should have main function");
        content.Should().Contain("main", "Should call main function");
    }

    [Fact]
    public void ProvisioningScript_EncodesCloudInit()
    {
        // Arrange
        var scriptPath = Path.Combine(_testDataPath, "provisioning.sh");
        var content = File.ReadAllText(scriptPath);

        // Act & Assert
        content.Should().Contain("encode_cloud_init", "Should have cloud-init encoding function");
        content.Should().Contain("base64", "Should use base64 encoding");
    }
}
