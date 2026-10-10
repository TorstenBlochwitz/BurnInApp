using System;
using System.IO;

namespace BurnIn.Shared
{
    public static class BurnInPathProvider
    {
        public static string GetConfigDirectory(string applicationName)
        {
            if (OperatingSystem.IsWindows())
            {
                return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), applicationName);
            }

            string? xdgConfigHome = Environment.GetEnvironmentVariable("XDG_CONFIG_HOME");
            if (!string.IsNullOrWhiteSpace(xdgConfigHome))
            {
                return Path.Combine(xdgConfigHome, applicationName);
            }

            return Path.Combine(GetHomeDirectory(), ".config", applicationName);
        }

        public static string GetDataDirectory(string applicationName)
        {
            if (OperatingSystem.IsWindows())
            {
                return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), applicationName);
            }

            string? xdgDataHome = Environment.GetEnvironmentVariable("XDG_DATA_HOME");
            if (!string.IsNullOrWhiteSpace(xdgDataHome))
            {
                return Path.Combine(xdgDataHome, applicationName);
            }

            return Path.Combine(GetHomeDirectory(), ".local", "share", applicationName);
        }

        private static string GetHomeDirectory()
        {
            string home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            if (!string.IsNullOrWhiteSpace(home))
            {
                return home;
            }

            home = Environment.GetEnvironmentVariable("HOME") ?? string.Empty;
            if (!string.IsNullOrWhiteSpace(home))
            {
                return home;
            }

            return AppContext.BaseDirectory;
        }
    }
}
