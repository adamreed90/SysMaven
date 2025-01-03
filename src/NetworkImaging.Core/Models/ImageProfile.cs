namespace NetworkImaging.Core.Models
{
    public class ImageProfile
    {
        public string ImageName { get; set; }
        public long ImageSize { get; set; }
        public string FileSystem { get; set; }
        public string CompressionType { get; set; }
        public string Description { get; set; }
    }
}
