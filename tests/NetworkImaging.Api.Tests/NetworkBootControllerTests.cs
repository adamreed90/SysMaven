using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Moq;
using NetworkImaging.Api.Controllers;
using NetworkImaging.Core.Interfaces;
using NetworkImaging.Core.Models;
using Xunit;

namespace NetworkImaging.Api.Tests
{
    public class NetworkBootControllerTests
    {
        private readonly Mock<INetworkBootService> _mockNetworkBootService;
        private readonly NetworkBootController _controller;

        public NetworkBootControllerTests()
        {
            _mockNetworkBootService = new Mock<INetworkBootService>();
            _controller = new NetworkBootController(_mockNetworkBootService.Object);
        }

        [Fact]
        public async Task ConfigureNetworkBoot_ValidConfig_ReturnsOk()
        {
            // Arrange
            var config = new NetworkConfig
            {
                IpAddress = "192.168.1.100",
                SubnetMask = "255.255.255.0",
                Gateway = "192.168.1.1",
                ServerAddress = "192.168.1.10"
            };

            _mockNetworkBootService.Setup(service => service.ConfigureNetworkBootAsync(config))
                .Returns(Task.CompletedTask);

            // Act
            var result = await _controller.ConfigureNetworkBoot(config);

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            Assert.Equal("Network boot configured successfully.", okResult.Value);
        }

        [Fact]
        public async Task ConfigureNetworkBoot_NullConfig_ReturnsBadRequest()
        {
            // Act
            var result = await _controller.ConfigureNetworkBoot(null);

            // Assert
            var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
            Assert.Equal("Invalid input parameters.", badRequestResult.Value);
        }

        [Fact]
        public async Task ConfigureNetworkBoot_ServiceThrowsException_ReturnsInternalServerError()
        {
            // Arrange
            var config = new NetworkConfig
            {
                IpAddress = "192.168.1.100",
                SubnetMask = "255.255.255.0",
                Gateway = "192.168.1.1",
                ServerAddress = "192.168.1.10"
            };

            _mockNetworkBootService.Setup(service => service.ConfigureNetworkBootAsync(config))
                .ThrowsAsync(new System.Exception("Test exception"));

            // Act
            var result = await _controller.ConfigureNetworkBoot(config);

            // Assert
            var internalServerErrorResult = Assert.IsType<ObjectResult>(result);
            Assert.Equal(500, internalServerErrorResult.StatusCode);
            Assert.Equal("Internal server error: Test exception", internalServerErrorResult.Value);
        }
    }
}
