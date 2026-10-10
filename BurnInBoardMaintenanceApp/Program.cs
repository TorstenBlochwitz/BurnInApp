using Avalonia;
using BurnIn.Shared;
using System;
using System.Globalization;

namespace BurnInBoardMaintenanceApp
{
    internal class Program
    {
        [STAThread]
        public static void Main(string[] args)
        {
            BurnInSharedContext.ApplicationName = "BurnInBoardMaintenanceApp";
            CultureInfo.DefaultThreadCurrentCulture = CultureInfo.InvariantCulture;
            CultureInfo.DefaultThreadCurrentUICulture = CultureInfo.InvariantCulture;
            CultureInfo.CurrentCulture = CultureInfo.InvariantCulture;
            CultureInfo.CurrentUICulture = CultureInfo.InvariantCulture;

            BuildAvaloniaApp().StartWithClassicDesktopLifetime(args);
        }

        public static AppBuilder BuildAvaloniaApp()
            => AppBuilder.Configure<App>()
                .UsePlatformDetect()
#if DEBUG
                .WithDeveloperTools()
#endif
                .WithInterFont()
                .LogToTrace();
    }
}
