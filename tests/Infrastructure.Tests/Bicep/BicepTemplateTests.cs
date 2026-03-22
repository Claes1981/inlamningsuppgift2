using Xunit;
using FluentAssertions;
using System.IO;
using System.Text.Json;

namespace Infrastructure.Tests.Bicep;

public class BicepTemplateTests
{
    private readonly string _testDataPath;

    public BicepTemplateTests()
    {
        // Get the path to the infrastructure files
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
    public void BicepFile_Exists()
    {
        // Arrange
        var bicepPath = Path.Combine(_testDataPath, "infrastructure.bicep");

        // Act & Assert
        File.Exists(bicepPath).Should().BeTrue("Bicep template file should exist");
    }

    [Fact]
    public void BicepFile_ContainsRequiredResources()
    {
        // Arrange
        var bicepPath = Path.Combine(_testDataPath, "infrastructure.bicep");
        var content = File.ReadAllText(bicepPath);

        // Act & Assert
        content.Should().Contain("Microsoft.Network/virtualNetworks", "Should contain Virtual Network resource");
        content.Should().Contain("Microsoft.Network/networkSecurityGroups", "Should contain NSG resource");
        content.Should().Contain("Microsoft.Network/applicationSecurityGroups", "Should contain ASG resources");
        content.Should().Contain("Microsoft.Compute/virtualMachines", "Should contain VM resources");
        content.Should().Contain("Microsoft.Network/networkInterfaces", "Should contain NIC resources");
        content.Should().Contain("Microsoft.Network/publicIPAddresses", "Should contain Public IP resources");
    }

    [Fact]
    public void BicepFile_ContainsRequiredParameters()
    {
        // Arrange
        var bicepPath = Path.Combine(_testDataPath, "infrastructure.bicep");
        var content = File.ReadAllText(bicepPath);

        // Act & Assert
        content.Should().Contain("param location", "Should have location parameter");
        content.Should().Contain("param adminPublicKey", "Should have admin public key parameter");
        content.Should().Contain("@secure()", "Should mark sensitive parameters as secure");
    }

    [Fact]
    public void BicepFile_ContainsOutputs()
    {
        // Arrange
        var bicepPath = Path.Combine(_testDataPath, "infrastructure.bicep");
        var content = File.ReadAllText(bicepPath);

        // Act & Assert
        content.Should().Contain("output", "Should contain outputs");
        content.Should().Contain("PublicIp", "Should output public IPs");
        content.Should().Contain("PrivateIp", "Should output private IPs");
    }

    [Fact]
    public void BicepFile_UsesLatestApiVersions()
    {
        // Arrange
        var bicepPath = Path.Combine(_testDataPath, "infrastructure.bicep");
        var content = File.ReadAllText(bicepPath);

        // Act & Assert
        content.Should().Contain("2024-", "Should use 2024 API versions");
    }

    [Fact]
    public void BicepFile_ContainsNsgSecurityRules()
    {
        // Arrange
        var bicepPath = Path.Combine(_testDataPath, "infrastructure.bicep");
        var content = File.ReadAllText(bicepPath);

        // Act & Assert
        content.Should().Contain("securityRules", "Should contain NSG security rules");
        content.Should().Contain("AllowSSH", "Should allow SSH access");
        content.Should().Contain("AllowHTTP", "Should allow HTTP access");
    }

    [Fact]
    public void CompiledJsonFile_Exists()
    {
        // Arrange
        var jsonPath = Path.Combine(_testDataPath, "infrastructure.json");

        // Act & Assert
        File.Exists(jsonPath).Should().BeTrue("Compiled JSON template should exist");
    }

    [Fact]
    public void CompiledJsonFile_IsValidJson()
    {
        // Arrange
        var jsonPath = Path.Combine(_testDataPath, "infrastructure.json");
        var content = File.ReadAllText(jsonPath);

        // Act
        var document = JsonDocument.Parse(content);

        // Assert
        document.Should().NotBeNull("JSON should be valid");
    }

    [Fact]
    public void CompiledJsonFile_ContainsResources()
    {
        // Arrange
        var jsonPath = Path.Combine(_testDataPath, "infrastructure.json");
        var content = File.ReadAllText(jsonPath);
        var document = JsonDocument.Parse(content);

        // Act
        var root = document.RootElement;
        bool hasResources = root.TryGetProperty("resources", out var resources);

        // Assert
        hasResources.Should().BeTrue("JSON should contain resources array");
        resources.ValueKind.Should().Be(System.Text.Json.JsonValueKind.Array, "Resources should be an array");
        resources.GetArrayLength().Should().BeGreaterThan(0, "Should have at least one resource");
    }
}
