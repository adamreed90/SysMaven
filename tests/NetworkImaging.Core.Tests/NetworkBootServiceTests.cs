using System.Threading.Tasks;
using NetworkImaging.Core.Interfaces;
using NetworkImaging.Core.Models;
using NetworkImaging.Core.Services;
using Xunit;

namespace NetworkImaging.Core.Tests
{
    public class NetworkBootServiceTests
    {
        private readonly INetworkBootService _networkBootService;

        public NetworkBootServiceTests()
        {
            _networkBootService = new NetworkBootService("/tmp/ipxe.script", "/tmp/boot.iso");
        }

        [Fact]
        public async Task ConfigureNetworkBootAsync_ValidConfig_ShouldConfigureSuccessfully()
        {
            // Arrange
            var config = new NetworkConfig
            {
                IpAddress = "192.168.1.100",
                SubnetMask = "255.255.255.0",
                Gateway = "192.168.1.1"
            };

            // Act
            await _networkBootService.ConfigureNetworkBootAsync(config);

            // Assert
            // Add appropriate assertions to verify the configuration
        }

        [Fact]
        public async Task ConfigureNetworkBootAsync_InvalidConfig_ShouldThrowException()
        {
            // Arrange
            var config = new NetworkConfig
            {
                IpAddress = null,
                SubnetMask = "255.255.255.0",
                Gateway = "192.168.1.1"
            };

            // Act & Assert
            await Assert.ThrowsAsync<ArgumentException>(() => _networkBootService.ConfigureNetworkBootAsync(config));
        }
    }
}
