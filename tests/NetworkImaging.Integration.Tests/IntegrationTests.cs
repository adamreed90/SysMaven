using System;
using System.Net.Http;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;
using NetworkImaging.Api;
using NetworkImaging.Core.Interfaces;
using NetworkImaging.Core.Models;
using NetworkImaging.Core.Services;

namespace NetworkImaging.Integration.Tests
{
    public class IntegrationTests : IClassFixture<WebApplicationFactory<Startup>>
    {
        private readonly HttpClient _client;
        private readonly IImageService _imageService;
        private readonly INetworkBootService _networkBootService;
        private readonly IStorageService _storageService;

        public IntegrationTests(WebApplicationFactory<Startup> factory)
        {
            _client = factory.CreateClient();
            _imageService = new ImageService();
            _networkBootService = new NetworkBootService();
            _storageService = new StorageService();
        }

        [Fact]
        public async Task TestImageCreationAndRestoration()
        {
            var profile = new ImageProfile { FileSystem = "ext4" };
            var sourceDevice = "/dev/sda";
            var destinationPath = "/mnt/image.img";

            await _imageService.CreateImageAsync(sourceDevice, destinationPath, profile);

            var imagePath = "/mnt/image.img";
            var targetDevice = "/dev/sdb";

            await _imageService.RestoreImageAsync(imagePath, targetDevice, profile);
        }

        [Fact]
        public async Task TestNetworkBootConfiguration()
        {
            var config = new NetworkConfig
            {
                IpAddress = "192.168.1.100",
                SubnetMask = "255.255.255.0",
                Gateway = "192.168.1.1",
                ServerAddress = "192.168.1.200"
            };

            await _networkBootService.ConfigureNetworkBootAsync(config);
        }

        [Fact]
        public async Task TestStorageManagement()
        {
            var device = "/dev/sda";
            var partitionType = "primary";
            var size = 1024L;

            await _storageService.CreatePartition(device, partitionType, size);

            var partition = "/dev/sda1";
            var fileSystem = "ext4";

            await _storageService.FormatPartition(partition, fileSystem);

            var mountPoint = "/mnt/test";

            await _storageService.MountPartition(partition, mountPoint);
            await _storageService.UnmountPartition(mountPoint);
        }
    }
}
