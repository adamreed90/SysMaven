using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using NetworkImaging.Core.Interfaces;
using NetworkImaging.Core.Models;

namespace NetworkImaging.Core.Services
{
    public class ImageService : IImageService
    {
        public async Task CreateImageAsync(string sourceDevice, string destinationPath, ImageProfile profile)
        {
            if (string.IsNullOrEmpty(sourceDevice) || string.IsNullOrEmpty(destinationPath))
            {
                throw new ArgumentException("Source device and destination path must be provided.");
            }

            var partcloneCommand = $"partclone.{profile.FileSystem} -c -s {sourceDevice} -o {destinationPath}";
            await ExecuteCommandAsync(partcloneCommand);
        }

        public async Task RestoreImageAsync(string imagePath, string targetDevice, ImageProfile profile)
        {
            if (string.IsNullOrEmpty(imagePath) || string.IsNullOrEmpty(targetDevice))
            {
                throw new ArgumentException("Image path and target device must be provided.");
            }

            var partcloneCommand = $"partclone.{profile.FileSystem} -r -s {imagePath} -o {targetDevice}";
            await ExecuteCommandAsync(partcloneCommand);
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
