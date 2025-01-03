using Microsoft.AspNetCore.Mvc;
using NetworkImaging.Core.Interfaces;
using NetworkImaging.Core.Models;
using System.Threading.Tasks;

namespace NetworkImaging.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ImageController : ControllerBase
    {
        private readonly IImageService _imageService;

        public ImageController(IImageService imageService)
        {
            _imageService = imageService;
        }

        [HttpPost("create")]
        public async Task<IActionResult> CreateImage([FromBody] ImageProfile profile, [FromQuery] string sourceDevice, [FromQuery] string destinationPath)
        {
            if (profile == null || string.IsNullOrEmpty(sourceDevice) || string.IsNullOrEmpty(destinationPath))
            {
                return BadRequest("Invalid input parameters.");
            }

            try
            {
                await _imageService.CreateImageAsync(sourceDevice, destinationPath, profile);
                return Ok("Image created successfully.");
            }
            catch (System.Exception ex)
            {
                return StatusCode(500, $"Internal server error: {ex.Message}");
            }
        }

        [HttpPost("restore")]
        public async Task<IActionResult> RestoreImage([FromBody] ImageProfile profile, [FromQuery] string imagePath, [FromQuery] string targetDevice)
        {
            if (profile == null || string.IsNullOrEmpty(imagePath) || string.IsNullOrEmpty(targetDevice))
            {
                return BadRequest("Invalid input parameters.");
            }

            try
            {
                await _imageService.RestoreImageAsync(imagePath, targetDevice, profile);
                return Ok("Image restored successfully.");
            }
            catch (System.Exception ex)
            {
                return StatusCode(500, $"Internal server error: {ex.Message}");
            }
        }
    }
}
