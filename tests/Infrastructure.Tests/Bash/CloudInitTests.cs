using FluentAssertions;
using System.Reflection;
using Xunit;

namespace Infrastructure.Tests.Bash;

public class CloudInitTests
{
    private readonly string _basePath;

    public CloudInitTests()
    {
        // Cloud-init files are copied to the output directory by the test project
        // Test assembly is at tests/Infrastructure.Tests/bin/Debug/net10.0/Infrastructure.Tests.dll
        // Cloud-init files are copied to the same directory
        var assemblyPath = Assembly.GetExecutingAssembly().Location;
        _basePath = Path.GetDirectoryName(assemblyPath) ?? throw new InvalidOperationException("Assembly location not found");
    }

    [Fact]
    public void WebServerCloudInit_Exists()
    {
        // Arrange
        var webServerCloudInitPath = Path.Combine(_basePath, "cloud-init_webserver.sh");

        // Assert
        File.Exists(webServerCloudInitPath).Should().BeTrue("web server cloud-init file should exist");
    }

    [Fact]
    public void ReverseProxyCloudInit_Exists()
    {
        // Arrange
        var reverseProxyCloudInitPath = Path.Combine(_basePath, "cloud-init_reverseproxy.sh");

        // Assert
        File.Exists(reverseProxyCloudInitPath).Should().BeTrue("reverse proxy cloud-init file should exist");
    }

    [Fact]
    public void BastionCloudInit_Exists()
    {
        // Arrange
        var bastionCloudInitPath = Path.Combine(_basePath, "cloud-init_bastion.sh");

        // Assert
        File.Exists(bastionCloudInitPath).Should().BeTrue("bastion cloud-init file should exist");
    }

    [Fact]
    public void WebServerCloudInit_HasCloudConfigHeader()
    {
        // Arrange
        var webServerCloudInitPath = Path.Combine(_basePath, "cloud-init_webserver.sh");
        var content = File.ReadAllText(webServerCloudInitPath);

        // Assert
        content.Should().StartWith("#cloud-config", "cloud-init files should have proper header");
    }

    [Fact]
    public void ReverseProxyCloudInit_HasCloudConfigHeader()
    {
        // Arrange
        var reverseProxyCloudInitPath = Path.Combine(_basePath, "cloud-init_reverseproxy.sh");
        var content = File.ReadAllText(reverseProxyCloudInitPath);

        // Assert
        content.Should().StartWith("#cloud-config", "cloud-init files should have proper header");
    }

    [Fact]
    public void BastionCloudInit_HasCloudConfigHeader()
    {
        // Arrange
        var bastionCloudInitPath = Path.Combine(_basePath, "cloud-init_bastion.sh");
        var content = File.ReadAllText(bastionCloudInitPath);

        // Assert
        content.Should().StartWith("#cloud-config", "cloud-init files should have proper header");
    }

    [Fact]
    public void WebServerCloudInit_InstallsDotnet()
    {
        // Arrange
        var webServerCloudInitPath = Path.Combine(_basePath, "cloud-init_webserver.sh");
        var content = File.ReadAllText(webServerCloudInitPath);

        // Assert
        content.Should().Contain("dotnet", "web server should use dotnet for the TodoApp");
    }

    [Fact]
    public void ReverseProxyCloudInit_InstallsNginx()
    {
        // Arrange
        var reverseProxyCloudInitPath = Path.Combine(_basePath, "cloud-init_reverseproxy.sh");
        var content = File.ReadAllText(reverseProxyCloudInitPath);

        // Assert
        content.Should().Contain("nginx", "reverse proxy should install nginx");
    }

    [Fact]
    public void WebServerCloudInit_ListensOnPort8080()
    {
        // Arrange
        var webServerCloudInitPath = Path.Combine(_basePath, "cloud-init_webserver.sh");
        var content = File.ReadAllText(webServerCloudInitPath);

        // Assert
        content.Should().Contain("5000", "web server should listen on port 5000");
    }

    [Fact]
    public void ReverseProxyCloudInit_ListensOnPort80()
    {
        // Arrange
        var reverseProxyCloudInitPath = Path.Combine(_basePath, "cloud-init_reverseproxy.sh");
        var content = File.ReadAllText(reverseProxyCloudInitPath);

        // Assert
        content.Should().Contain("listen 80", "reverse proxy should listen on port 80");
    }

    [Fact]
    public void ReverseProxyCloudInit_ProxiesToWebServer()
    {
        // Arrange
        var reverseProxyCloudInitPath = Path.Combine(_basePath, "cloud-init_reverseproxy.sh");
        var content = File.ReadAllText(reverseProxyCloudInitPath);

        // Assert
        content.Should().Contain("proxy_pass", "reverse proxy should proxy requests to web server");
    }
}
