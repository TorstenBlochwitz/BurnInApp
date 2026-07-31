namespace BurnInApp
{
    /// <summary>
    /// Status of one VDC channel of a board (as computed from the current profile step and measurement).
    /// Converted from MATLAB class by Torsten Blochwitz Electronics &amp; Software for InfraSolid
    /// </summary>
    public class VDCstatus
    {
        private VDCStatusEnum _status = VDCStatusEnum.UNKNOWN;
        // -1: too small, 0: OK, 1 too big
        private int _vdcMeasureStatus = 0;

        private static readonly double[] CWhite = { 1.0, 1.0, 1.0 };
        private static readonly double[] CGreen = { 0.0, 1.0, 0.0 };     // OK
        private static readonly double[] COrange = { 1.0, 0.8, 0.0 };    // User interaction required
        private static readonly double[] CFullRed = { 1.0, 0.0, 0.0 };   // Error (RGB LED)

        public void SetStatus(VDCStatusEnum v)
        {
            _status = v;
        }

        public VDCStatusEnum GetStatus()
        {
            return _status;
        }

        public void SetVDCmeasureStatus(int status)
        {
            _vdcMeasureStatus = status;
        }

        public (string ret, double[] color) GetStatusStringColor(double vdcMeasured)
        {
            string strV = vdcMeasured.ToString("F2");
            string ret;
            double[] color;
            switch (_status)
            {
                case VDCStatusEnum.OFF_SHOULD_BE_ON:
                    ret = "Error";
                    color = CFullRed;
                    break;
                case VDCStatusEnum.OFF_OK:
                    ret = "Off";
                    color = CGreen;
                    break;
                case VDCStatusEnum.ON_OK_V_CONTROLED:
                    ret = strV;
                    color = CGreen;
                    break;
                case VDCStatusEnum.ON_OK_P_CONTROLED:
                    ret = $"{strV} (P)";
                    color = CGreen;
                    break;
                case VDCStatusEnum.ON_PCONTROLED_V_LIMIT:
                    ret = $"{strV} (P \u2193V)";
                    color = COrange;
                    break;
                case VDCStatusEnum.ON_PCONTROLED_I_LIMIT:
                    ret = $"{strV} (P \u2193I)";
                    color = COrange;
                    break;
                default:
                    ret = "";
                    color = CWhite;
                    break;
            }

            if (_vdcMeasureStatus < 0)
            {
                ret = $"{strV} (\u2193)";
                color = CFullRed;
            }
            else if (_vdcMeasureStatus > 0)
            {
                ret = $"{strV} (\u2191)";
                color = CFullRed;
            }

            return (ret, color);
        }
    }
}
