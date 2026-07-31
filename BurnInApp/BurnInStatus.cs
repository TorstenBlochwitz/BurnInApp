namespace BurnInApp
{
    /// <summary>
    /// Holds the current status of a board.
    /// Converted from MATLAB class by Torsten Blochwitz Electronics &amp; Software for InfraSolid
    /// </summary>
    public class BurnInStatus
    {
        private BurnInStatusEnum _status = BurnInStatusEnum.NO_HARDWARE_CONNECTED;

        private static readonly string[] StrStatus =
        {
            "ERROR",
            "No Hardware connected",
            "DCDC Converter connected",
            "MainBoard Connected",
            "Executing Profile",
            "Switching Off"
        };

        public void SetStatus(BurnInStatusEnum v)
        {
            _status = v;
        }

        public BurnInStatusEnum GetStatus()
        {
            return _status;
        }

        public string GetStatusString()
        {
            return StrStatus[(int)_status + 1];
        }
    }
}
