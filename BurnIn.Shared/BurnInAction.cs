namespace BurnIn.Shared
{
    /// <summary>
    /// Holds the current and next action of a board's state machine.
    /// Converted from MATLAB class by Torsten Blochwitz Electronics &amp; Software for InfraSolid
    /// </summary>
    public class BurnInAction
    {
        public BurnInActionEnum CurrentAction { get; set; } = BurnInActionEnum.DO_NOTHING;
        public BurnInActionEnum NextAction { get; set; } = BurnInActionEnum.DO_NOTHING;

        private static readonly string[] StrAction =
        {
            "Doing nothing", "Connecting Hardware", "Connecting Hardware",
            "Self-testing", "Executing Profile", "Doing Measurement"
        };

        public string GetActionString()
        {
            return StrAction[(int)NextAction];
        }
    }
}

