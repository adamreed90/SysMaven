using Microsoft.AspNetCore.Http;
using System.IdentityModel.Tokens.Jwt;
using System.Linq;
using System.Threading.Tasks;

namespace NetworkImaging.Api.Middleware
{
    public class AuthenticationMiddleware
    {
        private readonly RequestDelegate _next;

        public AuthenticationMiddleware(RequestDelegate next)
        {
            _next = next;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            if (!context.Request.Headers.TryGetValue("Authorization", out var token))
            {
                context.Response.StatusCode = 401;
                await context.Response.WriteAsync("Authorization header missing.");
                return;
            }

            try
            {
                var jwtToken = new JwtSecurityTokenHandler().ReadToken(token) as JwtSecurityToken;
                if (jwtToken == null || !jwtToken.Claims.Any())
                {
                    context.Response.StatusCode = 401;
                    await context.Response.WriteAsync("Invalid token.");
                    return;
                }

                // Add claims to the context user
                context.User = new System.Security.Claims.ClaimsPrincipal(new System.Security.Claims.ClaimsIdentity(jwtToken.Claims, "jwt"));

                await _next(context);
            }
            catch
            {
                context.Response.StatusCode = 401;
                await context.Response.WriteAsync("Invalid token.");
            }
        }
    }
}
