namespace BurnIn.Shared
{
    /// <summary>
    /// Action a BurnInController performs for a given board.
    /// Converted from MATLAB class by Torsten Blochwitz Electronics &amp; Software for InfraSolid
    /// </summary>
    public enum BurnInActionEnum : byte
    {
        DO_NOTHING = 0,
        CONNECT_DCDC_CONVERTER = 1,
        CONNECT_MAINBOARD = 2,
        SELF_TEST = 3,
        CHECK_PROFILE = 4,
        DO_MEASUREMENT = 5
    }
}

