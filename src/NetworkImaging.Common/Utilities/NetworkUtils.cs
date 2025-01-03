using System;
using System.Diagnostics;
using System.Threading.Tasks;

namespace NetworkImaging.Common.Utilities
{
    public static class NetworkUtils
    {
        public static async Task<bool> ConfigureNetworkInterface(string interfaceName, string ipAddress, string subnetMask, string gateway)
        {
            try
            {
                string command = $"ip addr add {ipAddress}/{subnetMask} dev {interfaceName} && ip route add default via {gateway}";
                await RunCommandAsync(command);
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error configuring network interface: {ex.Message}");
                return false;
            }
        }

        public static async Task<bool> BringInterfaceUp(string interfaceName)
        {
            try
            {
                string command = $"ip link set {interfaceName} up";
                await RunCommandAsync(command);
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error bringing interface up: {ex.Message}");
                return false;
            }
        }

        public static async Task<bool> BringInterfaceDown(string interfaceName)
        {
            try
            {
                string command = $"ip link set {interfaceName} down";
                await RunCommandAsync(command);
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error bringing interface down: {ex.Message}");
                return false;
            }
        }

        private static async Task RunCommandAsync(string command)
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
                await process.WaitForExitAsync();

                if (process.ExitCode != 0)
                {
                    string error = await process.StandardError.ReadToEndAsync();
                    throw new Exception($"Command failed with exit code {process.ExitCode}: {error}");
                }
            }
        }
    }
}
