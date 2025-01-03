using System;
using System.IO;
using Microsoft.Extensions.Configuration;
using NetworkImaging.Configuration.Settings;

namespace NetworkImaging.Configuration.Providers
{
    public class ConfigurationProvider
    {
        private readonly IConfigurationRoot _configuration;

        public ConfigurationProvider()
        {
            var builder = new ConfigurationBuilder()
                .SetBasePath(Directory.GetCurrentDirectory())
                .AddJsonFile("appsettings.json", optional: true, reloadOnChange: true)
                .AddEnvironmentVariables();

            _configuration = builder.Build();
        }

        public AppSettings GetAppSettings()
        {
            var appSettings = new AppSettings();
            _configuration.GetSection("AppSettings").Bind(appSettings);
            return appSettings;
        }

        public NetworkSettings GetNetworkSettings()
        {
            var networkSettings = new NetworkSettings();
            _configuration.GetSection("NetworkSettings").Bind(networkSettings);
            return networkSettings;
        }

        public StorageSettings GetStorageSettings()
        {
            var storageSettings = new StorageSettings();
            _configuration.GetSection("StorageSettings").Bind(storageSettings);
            return storageSettings;
        }
    }
}
