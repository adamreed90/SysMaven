using System;
using System.Diagnostics;
using System.Threading.Tasks;

namespace NetworkImaging.Common.Utilities
{
    public static class ProcessUtils
    {
        public static async Task<bool> StartProcessAsync(string processName, string arguments)
        {
            try
            {
                var processInfo = new ProcessStartInfo(processName, arguments)
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
                        throw new Exception($"Process failed with exit code {process.ExitCode}: {error}");
                    }
                }

                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error starting process: {ex.Message}");
                return false;
            }
        }

        public static async Task<bool> StopProcessAsync(string processName)
        {
            try
            {
                var processInfo = new ProcessStartInfo("pkill", processName)
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
                        throw new Exception($"Process failed with exit code {process.ExitCode}: {error}");
                    }
                }

                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error stopping process: {ex.Message}");
                return false;
            }
        }
    }
}
