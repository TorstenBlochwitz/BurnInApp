namespace BurnInBoardMaintenanceApp
{
    internal sealed class DcdcStatusRow
    {
        public string Channel { get; init; } = string.Empty;
        public string Cml { get; set; } = "n/a";
        public string Word { get; set; } = "n/a";
        public string VoutStatus { get; set; } = "n/a";
        public string InputStatus { get; set; } = "n/a";
        public string Vdc { get; set; } = "n/a";
        public string Iout { get; set; } = "n/a";
        public string Vin { get; set; } = "n/a";
        public string Iin { get; set; } = "n/a";
        public string Temperature { get; set; } = "n/a";
    }
}
