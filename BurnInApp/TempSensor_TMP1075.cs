using System;

namespace BurnInApp
{
    /// <summary>
    /// TempSensor_TMP1075: support functions for the temperature sensor TMP1075.
    /// Converted from the MATLAB class TempSensor_TMP1075 by Torsten Blochwitz Electronics &amp; Software for InfraSolid.
    /// </summary>
    public class TempSensor_TMP1075 : SMBusDev
    {
        public TempSensor_TMP1075(MBC_TB mbc, int address, int offset, int mpAddr, int cOn, int cOff)
            : base(mbc, address, offset, mpAddr, cOn, cOff, false)
        {
            // Device is by default in continuous conversion mode with a sample rate of 27.5 ms
        }

        public double GetTemperatureCelsius()
        {
            double temp = -273.5;
            if (Connected)
            {
                temp = ReadWord(0) * 0.0625 / 16;
            }
            return temp;
        }
    }
}
