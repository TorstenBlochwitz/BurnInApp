namespace BurnIn.Shared
{
    /// <summary>
    /// Status of a burn-in profile
    /// Converted from MATLAB class by Torsten Blochwitz Electronics & Software for InfraSolid
    /// </summary>
    public enum ProfileStatusEnum : byte
    {
        EMPTY = 0,
        READY_TO_RUN = 1,
        RUNNING = 2,
        STOPPED_MANUALLY = 3,
        STOPPED_ERROR = 4,
        STOPPED_SHORTCIRCUIT = 5,
        FINISHED = 6,
        RUN_REQUESTED = 7,
        STOP_REQUESTED_ERROR = 8,
        STOP_REQUESTED_MANUALLY = 9,
        CONTINUE_REQUESTED = 10,
        CONTINUE_REQUESTED_AFTER_ERROR = 11,
        RESET_REQUESTED = 12
    }
}

