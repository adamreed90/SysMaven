using Microsoft.AspNetCore.Http;
using System.Diagnostics;
using System.Threading.Tasks;

namespace NetworkImaging.Api.Middleware
{
    public class LoggingMiddleware
    {
        private readonly RequestDelegate _next;

        public LoggingMiddleware(RequestDelegate next)
        {
            _next = next;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            var stopwatch = new Stopwatch();
            stopwatch.Start();

            // Log request details
            LogRequest(context);

            await _next(context);

            stopwatch.Stop();

            // Log response details
            LogResponse(context, stopwatch.ElapsedMilliseconds);
        }

        private void LogRequest(HttpContext context)
        {
            var request = context.Request;
            var logMessage = $"Request: {request.Method} {request.Path} {request.QueryString}";
            // Use syslog-ng for logging
            SyslogNgLogger.Log(logMessage);
        }

        private void LogResponse(HttpContext context, long elapsedMilliseconds)
        {
            var response = context.Response;
            var logMessage = $"Response: {response.StatusCode} {elapsedMilliseconds}ms";
            // Use syslog-ng for logging
            SyslogNgLogger.Log(logMessage);
        }
    }

    public static class SyslogNgLogger
    {
        public static void Log(string message)
        {
            // Placeholder for syslog-ng logging implementation
            // This should send the log message to syslog-ng
        }
    }
}
