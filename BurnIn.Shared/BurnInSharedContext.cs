namespace BurnIn.Shared
{
    public static class BurnInSharedContext
    {
        public static string ApplicationName { get; set; } = "BurnInApp";

        public static string GetConfigDirectory()
        {
            return BurnInPathProvider.GetConfigDirectory(ApplicationName);
        }

        public static string GetDataDirectory()
        {
            return BurnInPathProvider.GetDataDirectory(ApplicationName);
        }
    }
}
