namespace BurnIn.Shared
{
    /// <summary>
    /// Status of a VDC (channel voltage) as computed from a burn-in profile step
    /// Converted from MATLAB class by Torsten Blochwitz Electronics & Software for InfraSolid
    /// </summary>
    public enum VDCStatusEnum : sbyte
    {
        OFF_SHOULD_BE_ON = -1,
        OFF_OK = 0,
        ON_OK_V_CONTROLED = 1,
        ON_OK_P_CONTROLED = 2,
        ON_PCONTROLED_V_LIMIT = 3,
        ON_PCONTROLED_I_LIMIT = 4,
        UNKNOWN = 5,
        VDC_NOT_AVAILABLE = 6
    }
}

