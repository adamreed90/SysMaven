namespace NetworkImaging.Core.Interfaces
{
    public interface IImageService
    {
        Task CreateImageAsync(string sourceDevice, string destinationPath, ImageProfile profile);
        Task RestoreImageAsync(string imagePath, string targetDevice, ImageProfile profile);
    }
}
