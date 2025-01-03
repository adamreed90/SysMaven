using System;
using System.Net.NetworkInformation;
using System.Threading.Tasks;

namespace NetworkImaging.Common.Extensions
{
    public static class NetworkExtensions
    {
        public static async Task<bool> IsNetworkAvailableAsync()
        {
            return await Task.Run(() => NetworkInterface.GetIsNetworkAvailable());
        }

        public static async Task<string> GetMacAddressAsync(this NetworkInterface networkInterface)
        {
            return await Task.Run(() => BitConverter.ToString(networkInterface.GetPhysicalAddress().GetAddressBytes()));
        }

        public static async Task<string> GetIpAddressAsync(this NetworkInterface networkInterface)
        {
            return await Task.Run(() =>
            {
                var ipProperties = networkInterface.GetIPProperties();
                foreach (var ip in ipProperties.UnicastAddresses)
                {
                    if (ip.Address.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork)
                    {
                        return ip.Address.ToString();
                    }
                }
                return string.Empty;
            });
        }
    }
}
