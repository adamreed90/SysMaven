using System;
using System.Diagnostics;
using System.Threading.Tasks;

namespace NetworkImaging.Common.Utilities
{
    public static class DiskUtils
    {
        public static async Task<bool> CreatePartition(string device, string partitionType, long size)
        {
            try
            {
                string command = $"parted {device} mkpart {partitionType} 0% {size}MB";
                await RunCommandAsync(command);
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error creating partition: {ex.Message}");
                return false;
            }
        }

        public static async Task<bool> FormatPartition(string partition, string fileSystem)
        {
            try
            {
                string command = $"mkfs.{fileSystem} {partition}";
                await RunCommandAsync(command);
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error formatting partition: {ex.Message}");
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
