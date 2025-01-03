using System;
using System.IO;
using System.Threading.Tasks;
using NetworkImaging.Core.Interfaces;
using NetworkImaging.Core.Models;
using NetworkImaging.Core.Services;
using Xunit;

namespace NetworkImaging.Core.Tests
{
    public class ImageServiceTests
    {
        private readonly IImageService _imageService;

        public ImageServiceTests()
        {
            _imageService = new ImageService();
        }

        [Fact]
        public async Task CreateImageAsync_ValidParameters_ShouldCreateImage()
        {
            // Arrange
            string sourceDevice = "/dev/sda1";
            string destinationPath = "/tmp/image.img";
            var profile = new ImageProfile
            {
                FileSystem = "ext4",
                ImageName = "TestImage",
                ImageSize = 1024,
                CompressionType = "gzip",
                Description = "Test image creation"
            };

            // Act
            await _imageService.CreateImageAsync(sourceDevice, destinationPath, profile);

            // Assert
            Assert.True(File.Exists(destinationPath));
        }

        [Fact]
        public async Task RestoreImageAsync_ValidParameters_ShouldRestoreImage()
        {
            // Arrange
            string imagePath = "/tmp/image.img";
            string targetDevice = "/dev/sda1";
            var profile = new ImageProfile
            {
                FileSystem = "ext4",
                ImageName = "TestImage",
                ImageSize = 1024,
                CompressionType = "gzip",
                Description = "Test image restoration"
            };

            // Act
            await _imageService.RestoreImageAsync(imagePath, targetDevice, profile);

            // Assert
            // Add appropriate assertions to verify the restoration
        }

        [Fact]
        public async Task CreateImageAsync_InvalidParameters_ShouldThrowArgumentException()
        {
            // Arrange
            string sourceDevice = null;
            string destinationPath = "/tmp/image.img";
            var profile = new ImageProfile
            {
                FileSystem = "ext4",
                ImageName = "TestImage",
                ImageSize = 1024,
                CompressionType = "gzip",
                Description = "Test image creation"
            };

            // Act & Assert
            await Assert.ThrowsAsync<ArgumentException>(() => _imageService.CreateImageAsync(sourceDevice, destinationPath, profile));
        }

        [Fact]
        public async Task RestoreImageAsync_InvalidParameters_ShouldThrowArgumentException()
        {
            // Arrange
            string imagePath = null;
            string targetDevice = "/dev/sda1";
            var profile = new ImageProfile
            {
                FileSystem = "ext4",
                ImageName = "TestImage",
                ImageSize = 1024,
                CompressionType = "gzip",
                Description = "Test image restoration"
            };

            // Act & Assert
            await Assert.ThrowsAsync<ArgumentException>(() => _imageService.RestoreImageAsync(imagePath, targetDevice, profile));
        }
    }
}
