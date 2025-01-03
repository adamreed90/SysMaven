using System.Threading.Tasks;
using NetworkImaging.Core.Models;

namespace NetworkImaging.Core.Interfaces
{
    public interface INetworkBootService
    {
        Task ConfigureNetworkBootAsync(NetworkConfig config);
    }
}
