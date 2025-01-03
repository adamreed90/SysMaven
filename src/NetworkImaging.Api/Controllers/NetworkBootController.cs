using Microsoft.AspNetCore.Mvc;
using NetworkImaging.Core.Interfaces;
using NetworkImaging.Core.Models;
using System.Threading.Tasks;

namespace NetworkImaging.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class NetworkBootController : ControllerBase
    {
        private readonly INetworkBootService _networkBootService;

        public NetworkBootController(INetworkBootService networkBootService)
        {
            _networkBootService = networkBootService;
        }

        [HttpPost("configure")]
        public async Task<IActionResult> ConfigureNetworkBoot([FromBody] NetworkConfig config)
        {
            if (config == null)
            {
                return BadRequest("Invalid input parameters.");
            }

            try
            {
                await _networkBootService.ConfigureNetworkBootAsync(config);
                return Ok("Network boot configured successfully.");
            }
            catch (System.Exception ex)
            {
                return StatusCode(500, $"Internal server error: {ex.Message}");
            }
        }
    }
}
