using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Moq;
using NetworkImaging.Api.Controllers;
using NetworkImaging.Core.Models;
using Xunit;

namespace NetworkImaging.Api.Tests
{
    public class SystemControllerTests
    {
        private readonly SystemController _systemController;

        public SystemControllerTests()
        {
            _systemController = new SystemController();
        }

        [Fact]
        public async Task GetSystemStatus_ReturnsOk()
        {
            // Act
            var result = _systemController.GetSystemStatus();

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            var systemStatus = Assert.IsType<SystemStatus>(okResult.Value);
            Assert.NotNull(systemStatus);
        }
    }
}
