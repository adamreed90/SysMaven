using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using NetworkImaging.Core.Interfaces;
using NetworkImaging.Core.Models;
using NetworkImaging.Common.Utilities;

namespace NetworkImaging.Core.Services
{
    public class MulticastService
    {
        private readonly string _dnsmasqConfigPath;
        private readonly string _multicastImagePath;

        public MulticastService(string dnsmasqConfigPath, string multicastImagePath)
        {
            _dnsmasqConfigPath = dnsmasqConfigPath;
            _multicastImagePath = multicastImagePath;
        }

        public async Task ConfigureMulticastAsync(NetworkConfig config)
        {
            // Configure dnsmasq for multicast
            await ConfigureDnsmasqAsync(config);
        }

        private async Task ConfigureDnsmasqAsync(NetworkConfig config)
        {
            // Generate dnsmasq configuration
            var dnsmasqConfig = GenerateDnsmasqConfig(config);
            await File.WriteAllTextAsync(_dnsmasqConfigPath, dnsmasqConfig);
        }

        private string GenerateDnsmasqConfig(NetworkConfig config)
        {
            return $@"
interface=eth0
bind-interfaces
dhcp-range={config.IpAddress},{config.IpAddress},12h
enable-tftp
tftp-root=/var/lib/tftpboot
pxe-service=x86PC, "Network Boot", pxelinux
pxe-service=x86-64_EFI, "Network Boot", bootx64.efi
";
        }

        public async Task StartMulticastAsync()
        {
            var command = $"dnsmasq --conf-file={_dnsmasqConfigPath}";
            await ExecuteCommandAsync(command);
        }

        private async Task ExecuteCommandAsync(string command)
        {
            var processInfo = new ProcessStartInfo("bash", $"-c \"{command}\"")
            {
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            using (var process = new Process { StartInfo = processInfo })
            {
                process.Start();
                string output = await process.StandardOutput.ReadToEndAsync();
                string error = await process.StandardError.ReadToEndAsync();
                process.WaitForExit();

                if (process.ExitCode != 0)
                {
                    throw new InvalidOperationException($"Command failed with exit code {process.ExitCode}: {error}");
                }
            }
        }
    }
}
