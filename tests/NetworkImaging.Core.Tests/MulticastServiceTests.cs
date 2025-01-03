using System.Threading.Tasks;
using NetworkImaging.Core.Models;
using NetworkImaging.Core.Services;
using Xunit;

namespace NetworkImaging.Core.Tests
{
    public class MulticastServiceTests
    {
        private readonly MulticastService _multicastService;

        public MulticastServiceTests()
        {
            _multicastService = new MulticastService("/tmp/dnsmasq.conf", "/tmp/multicast.img");
        }

        [Fact]
        public async Task ConfigureMulticastAsync_ValidConfig_ShouldConfigureSuccessfully()
        {
            // Arrange
            var config = new NetworkConfig
            {
                IpAddress = "192.168.1.100",
                SubnetMask = "255.255.255.0",
                Gateway = "192.168.1.1"
            };

            // Act
            await _multicastService.ConfigureMulticastAsync(config);

            // Assert
            // Add appropriate assertions to verify the configuration
        }

        [Fact]
        public async Task ConfigureMulticastAsync_InvalidConfig_ShouldThrowException()
        {
            // Arrange
            var config = new NetworkConfig
            {
                IpAddress = null,
                SubnetMask = "255.255.255.0",
                Gateway = "192.168.1.1"
            };

            // Act & Assert
            await Assert.ThrowsAsync<ArgumentException>(() => _multicastService.ConfigureMulticastAsync(config));
        }

        [Fact]
        public async Task StartMulticastAsync_ShouldStartSuccessfully()
        {
            // Act
            await _multicastService.StartMulticastAsync();

            // Assert
            // Add appropriate assertions to verify the multicast start
        }
    }
}
