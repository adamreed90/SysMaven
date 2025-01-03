namespace NetworkImaging.Configuration.Settings
{
    public class AppSettings
    {
        public LoggingSettings Logging { get; set; }
        public AuthenticationSettings Authentication { get; set; }
        public string ApplicationName { get; set; }
        public string Version { get; set; }
    }

    public class LoggingSettings
    {
        public string LogLevel { get; set; }
        public string LogFilePath { get; set; }
    }

    public class AuthenticationSettings
    {
        public string JwtSecret { get; set; }
        public int TokenExpirationMinutes { get; set; }
    }
}
