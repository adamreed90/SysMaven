namespace NetworkImaging.Configuration.Settings
{
    public class StorageSettings
    {
        public string Device { get; set; }
        public string PartitionType { get; set; }
        public long PartitionSize { get; set; }
        public string FileSystem { get; set; }
        public string MountPoint { get; set; }
        public string VolumeGroup { get; set; }
        public string LogicalVolume { get; set; }
        public long LogicalVolumeSize { get; set; }
    }
}
