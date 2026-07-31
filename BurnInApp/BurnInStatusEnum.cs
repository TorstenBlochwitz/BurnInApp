namespace BurnInApp
{
    /// <summary>
    /// Status of a board as tracked by the BurnInController.
    /// Converted from MATLAB class by Torsten Blochwitz Electronics &amp; Software for InfraSolid
    /// </summary>
    public enum BurnInStatusEnum : sbyte
    {
        ERROR = -1,
        NO_HARDWARE_CONNECTED = 0,
        DCDC_CONNECTED = 1,
        MAINBOARD_CONNECTED = 2,
        EXECUTING_PROFILE = 3,
        SWITCHING_OFF = 5
    }
}
