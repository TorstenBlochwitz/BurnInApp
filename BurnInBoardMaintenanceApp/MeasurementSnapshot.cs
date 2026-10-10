namespace BurnInBoardMaintenanceApp
{
    internal sealed class MeasurementSnapshot
    {
        public double AdcResistance { get; set; } = double.PositiveInfinity;
        public double AdcVoltage { get; set; } = double.PositiveInfinity;
    }
}
