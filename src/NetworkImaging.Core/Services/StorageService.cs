using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using NetworkImaging.Core.Interfaces;
using NetworkImaging.Core.Models;
using NetworkImaging.Common.Utilities;

namespace NetworkImaging.Core.Services
{
    public class StorageService : IStorageService
    {
        public async Task<bool> CreatePartition(string device, string partitionType, long size)
        {
            try
            {
                string command = $"parted {device} mkpart {partitionType} 0% {size}MB";
                await ProcessUtils.RunCommandAsync(command);
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error creating partition: {ex.Message}");
                return false;
            }
        }

        public async Task<bool> FormatPartition(string partition, string fileSystem)
        {
            try
            {
                string command = $"mkfs.{fileSystem} {partition}";
                await ProcessUtils.RunCommandAsync(command);
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error formatting partition: {ex.Message}");
                return false;
            }
        }

        public async Task<bool> MountPartition(string partition, string mountPoint)
        {
            try
            {
                if (!Directory.Exists(mountPoint))
                {
                    Directory.CreateDirectory(mountPoint);
                }

                string command = $"mount {partition} {mountPoint}";
                await ProcessUtils.RunCommandAsync(command);
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error mounting partition: {ex.Message}");
                return false;
            }
        }

        public async Task<bool> UnmountPartition(string mountPoint)
        {
            try
            {
                string command = $"umount {mountPoint}";
                await ProcessUtils.RunCommandAsync(command);
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error unmounting partition: {ex.Message}");
                return false;
            }
        }

        public async Task<bool> CreateLogicalVolume(string volumeGroup, string logicalVolume, long size)
        {
            try
            {
                string command = $"lvcreate -L {size}M -n {logicalVolume} {volumeGroup}";
                await ProcessUtils.RunCommandAsync(command);
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error creating logical volume: {ex.Message}");
                return false;
            }
        }

        public async Task<bool> RemoveLogicalVolume(string volumeGroup, string logicalVolume)
        {
            try
            {
                string command = $"lvremove -f {volumeGroup}/{logicalVolume}";
                await ProcessUtils.RunCommandAsync(command);
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error removing logical volume: {ex.Message}");
                return false;
            }
        }

        public async Task<bool> ExtendLogicalVolume(string volumeGroup, string logicalVolume, long size)
        {
            try
            {
                string command = $"lvextend -L +{size}M {volumeGroup}/{logicalVolume}";
                await ProcessUtils.RunCommandAsync(command);
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error extending logical volume: {ex.Message}");
                return false;
            }
        }

        public async Task<bool> ReduceLogicalVolume(string volumeGroup, string logicalVolume, long size)
        {
            try
            {
                string command = $"lvreduce -L -{size}M {volumeGroup}/{logicalVolume}";
                await ProcessUtils.RunCommandAsync(command);
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error reducing logical volume: {ex.Message}");
                return false;
            }
        }
    }
}
