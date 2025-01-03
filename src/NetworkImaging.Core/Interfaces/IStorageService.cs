namespace NetworkImaging.Core.Interfaces
{
    public interface IStorageService
    {
        Task<bool> CreatePartition(string device, string partitionType, long size);
        Task<bool> FormatPartition(string partition, string fileSystem);
        Task<bool> MountPartition(string partition, string mountPoint);
        Task<bool> UnmountPartition(string mountPoint);
        Task<bool> CreateLogicalVolume(string volumeGroup, string logicalVolume, long size);
        Task<bool> RemoveLogicalVolume(string volumeGroup, string logicalVolume);
        Task<bool> ExtendLogicalVolume(string volumeGroup, string logicalVolume, long size);
        Task<bool> ReduceLogicalVolume(string volumeGroup, string logicalVolume, long size);
    }
}
