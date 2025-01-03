using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using NetworkImaging.Core.Interfaces;
using NetworkImaging.Core.Models;
using NetworkImaging.Common.Utilities;

namespace NetworkImaging.Core.Services
{
    public class NetworkBootService : INetworkBootService
    {
        private readonly string _ipxeScriptPath;
        private readonly string _isoPath;

        public NetworkBootService(string ipxeScriptPath, string isoPath)
        {
            _ipxeScriptPath = ipxeScriptPath;
            _isoPath = isoPath;
        }

        public async Task ConfigureNetworkBootAsync(NetworkConfig config)
        {
            // Configure network boot settings
            await ConfigureIpxeAsync(config);
            await ConfigureIsoAsync(config);
        }

        private async Task ConfigureIpxeAsync(NetworkConfig config)
        {
            // Generate iPXE script
            var ipxeScript = GenerateIpxeScript(config);
            await File.WriteAllTextAsync(_ipxeScriptPath, ipxeScript);
        }

        private string GenerateIpxeScript(NetworkConfig config)
        {
            return $@"
#!ipxe
dhcp
set net0/ip {config.IpAddress}
set net0/netmask {config.SubnetMask}
set net0/gateway {config.Gateway}
chain http://{config.ServerAddress}/boot.ipxe
";
        }

        private async Task ConfigureIsoAsync(NetworkConfig config)
        {
            // Generate ISO boot configuration
            var isoConfig = GenerateIsoConfig(config);
            await File.WriteAllTextAsync(_isoPath, isoConfig);
        }

        private string GenerateIsoConfig(NetworkConfig config)
        {
            return $@"
default menu.c32
prompt 0
timeout 50
ONTIMEOUT local

label local
    menu label Boot from local drive
    localboot 0

label network
    menu label Boot from network
    kernel http://{config.ServerAddress}/vmlinuz
    append initrd=http://{config.ServerAddress}/initrd.img root=/dev/ram0 rw
";
        }
    }
}
