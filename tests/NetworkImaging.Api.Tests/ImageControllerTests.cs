using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Moq;
using NetworkImaging.Api.Controllers;
using NetworkImaging.Core.Interfaces;
using NetworkImaging.Core.Models;
using Xunit;

namespace NetworkImaging.Api.Tests
{
    public class ImageControllerTests
    {
        private readonly Mock<IImageService> _mockImageService;
        private readonly ImageController _imageController;

        public ImageControllerTests()
        {
            _mockImageService = new Mock<IImageService>();
            _imageController = new ImageController(_mockImageService.Object);
        }

        [Fact]
        public async Task CreateImage_ValidParameters_ReturnsOk()
        {
            // Arrange
            var profile = new ImageProfile
            {
                ImageName = "TestImage",
                ImageSize = 1024,
                FileSystem = "ext4",
                CompressionType = "gzip",
                Description = "Test image creation"
            };
            string sourceDevice = "/dev/sda1";
            string destinationPath = "/tmp/image.img";

            _mockImageService.Setup(service => service.CreateImageAsync(sourceDevice, destinationPath, profile))
                .Returns(Task.CompletedTask);

            // Act
            var result = await _imageController.CreateImage(profile, sourceDevice, destinationPath);

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            Assert.Equal("Image created successfully.", okResult.Value);
        }

        [Fact]
        public async Task CreateImage_InvalidParameters_ReturnsBadRequest()
        {
            // Arrange
            ImageProfile profile = null;
            string sourceDevice = null;
            string destinationPath = null;

            // Act
            var result = await _imageController.CreateImage(profile, sourceDevice, destinationPath);

            // Assert
            var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
            Assert.Equal("Invalid input parameters.", badRequestResult.Value);
        }

        [Fact]
        public async Task RestoreImage_ValidParameters_ReturnsOk()
        {
            // Arrange
            var profile = new ImageProfile
            {
                ImageName = "TestImage",
                ImageSize = 1024,
                FileSystem = "ext4",
                CompressionType = "gzip",
                Description = "Test image restoration"
            };
            string imagePath = "/tmp/image.img";
            string targetDevice = "/dev/sda1";

            _mockImageService.Setup(service => service.RestoreImageAsync(imagePath, targetDevice, profile))
                .Returns(Task.CompletedTask);

            // Act
            var result = await _imageController.RestoreImage(profile, imagePath, targetDevice);

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            Assert.Equal("Image restored successfully.", okResult.Value);
        }

        [Fact]
        public async Task RestoreImage_InvalidParameters_ReturnsBadRequest()
        {
            // Arrange
            ImageProfile profile = null;
            string imagePath = null;
            string targetDevice = null;

            // Act
            var result = await _imageController.RestoreImage(profile, imagePath, targetDevice);

            // Assert
            var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
            Assert.Equal("Invalid input parameters.", badRequestResult.Value);
        }
    }
}
