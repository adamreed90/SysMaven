using System;
using System.IO;
using System.Threading.Tasks;

namespace NetworkImaging.Common.Extensions
{
    public static class ImageExtensions
    {
        public static async Task<bool> CopyImageAsync(string sourcePath, string destinationPath)
        {
            try
            {
                using (var sourceStream = new FileStream(sourcePath, FileMode.Open, FileAccess.Read))
                using (var destinationStream = new FileStream(destinationPath, FileMode.Create, FileAccess.Write))
                {
                    await sourceStream.CopyToAsync(destinationStream);
                }
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error copying image: {ex.Message}");
                return false;
            }
        }

        public static async Task<bool> DeleteImageAsync(string imagePath)
        {
            try
            {
                if (File.Exists(imagePath))
                {
                    File.Delete(imagePath);
                }
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error deleting image: {ex.Message}");
                return false;
            }
        }

        public static async Task<long> GetImageSizeAsync(string imagePath)
        {
            try
            {
                var fileInfo = new FileInfo(imagePath);
                return fileInfo.Length;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error getting image size: {ex.Message}");
                return -1;
            }
        }
    }
}
