using System;
using System.Threading;

namespace BurnIn.Shared
{
    /// <summary>
    /// ADC_ADS1115: support functions for the AD converter ADS1115.
    /// Converted from the MATLAB class ADC_ADS1115 by Torsten Blochwitz Electronics &amp; Software for InfraSolid.
    /// </summary>
    public class ADC_ADS1115
    {
        public MBC_TB? Mbc { get; private set; }
        public int Address { get; }
        public int Offset { get; }
        public bool Debug { get; set; } = false;
        public int MPAddr { get; } = 0xE0;
        public byte COn { get; }
        public byte COff { get; }
        public int NumRepeat { get; set; } = 5;

        public ADC_ADS1115(MBC_TB? mbc, int address, int offset, int mpAddr, byte cOn, byte cOff)
        {
            Mbc = mbc;
            Address = address;
            Offset = offset;
            MPAddr = mpAddr;
            COn = cOn;
            COff = cOff;
        }

        public bool UpdateRefToMBC(MBC_TB mbc)
        {
            Mbc = mbc;
            return true;
        }

        public double GetVoltage(ADS1115 configMux, ADS1115 gain)
        {
            double v = 0.0;

            using (new I2CMultiplexerPCA9542A(Mbc, Offset, MPAddr, COn, COff))
            {
                // reads single-ended voltage on channel 0 to mirror the current MATLAB logic
                // adapted from https://github.com/adafruit/Adafruit_ADS1X15
                ushort config = 0;
                config |= 0x0003; // ADS1X15_REG_CONFIG_CQUE_1CONV: Disable the comparator and put ALERT/RDY in high state (default)
                config |= 0x0000; // ADS1X15_REG_CONFIG_CLAT_NONLAT: Non-latching (default val)
                config |= 0x0000; // ADS1X15_REG_CONFIG_CPOL_ACTVLOW: Alert/Rdy active low   (default val)
                config |= 0x0000; // ADS1X15_REG_CONFIG_CMODE_TRAD: Traditional comparator (default val)
                config |= (ushort)ADS1115.ADS1X15_REG_CONFIG_MODE_CONTIN;
                config |= (ushort)gain;
                config |= 0x0080; // RATE_ADS1115_128SPS (default)
                config |= (ushort)configMux;
                config |= 0x8000; // ADS1X15_REG_CONFIG_OS_SINGLE: Set to start a single-conversion

                // write to config register
                Mbc!.WriteBytesI2C(Address, Offset, new byte[] { 0x01, (byte)(config >> 8), (byte)(config & 0xFF) });
                Thread.Sleep(500); // This is a try to wait some time before reading
                byte[] raw = Mbc.QueryBytesI2C(Address, Offset, 0x00, 1, 2);
                // convert to voltage, considering gain
                v = ComputeVolts(gain, raw);
            }

            return v;
        }

        public double GetVoltageDiff(ADS1115 configMux, ADS1115 gain)
        {
            double v = 0.0;

            configMux = ADS1115.CONFIG_MUX_SINGLE_0;

            using (new I2CMultiplexerPCA9542A(Mbc, Offset, MPAddr, COn, COff))
            {
                // reads differential voltage between channel 0 and 1
                // adapted from https://github.com/adafruit/Adafruit_ADS1X15
                ushort config = 0;
                config |= 0x0003; // ADS1X15_REG_CONFIG_CQUE_1CONV: Disable the comparator and put ALERT/RDY in high state (default)
                config |= 0x0000; // ADS1X15_REG_CONFIG_CLAT_NONLAT: Non-latching (default val)
                config |= 0x0000; // ADS1X15_REG_CONFIG_CPOL_ACTVLOW: Alert/Rdy active low   (default val)
                config |= 0x0000; // ADS1X15_REG_CONFIG_CMODE_TRAD: Traditional comparator (default val)
                config |= (ushort)ADS1115.ADS1X15_REG_CONFIG_MODE_CONTIN;
                config |= (ushort)gain;
                config |= 0x0080; // RATE_ADS1115_128SPS (default)
                config |= (ushort)configMux;

                // write to config register
                byte[] bytes = new byte[] { 0x01, (byte)(config >> 8), (byte)(config & 0xFF) };
                bool floating = false;

                for (int i = 1; i <= NumRepeat; i++)
                {
                    try
                    {
                        Mbc!.WriteBytesI2C(Address, Offset, bytes);

                        // check if config arrived correctly at ADS1115
                        byte[] status = Mbc.QueryBytesI2C(Address, Offset, 0x01, 1, 2);
                        if (!MBC_USB_TCP.IsEqualMask(status, new byte[] { bytes[1], bytes[2] }, new byte[] { 0b11111111, 0b11111110 }))
                        {
                            Mbc.HandleError("029");
                        }

                        // wait until conversion is complete
                        Thread.Sleep(100);

                        // read conversion result
                        byte[] raw1 = Mbc.QueryBytesI2C(Address, Offset, 0x00, 1, 2);
                        double v1 = ComputeVolts(gain, raw1);

                        // read a second time to check if we read correct values
                        byte[] raw2 = Mbc.QueryBytesI2C(Address, Offset, 0x00, 1, 2);
                        double v2 = ComputeVolts(gain, raw2);

                        if ((v1 > 5.1) || (v2 > 5.1))
                        {
                            floating = true;
                        }

                        if (Math.Abs(v1 - v2) < Math.Max(0.01, 0.1 * Math.Max(Math.Abs(v1), Math.Abs(v2))))
                        {
                            v = (v1 + v2) / 2;
                            return v;
                        }

                        if (i == NumRepeat && floating)
                        {
                            v = 0.0;
                            return v;
                        }

                        Mbc.HandleError("029");
                    }
                    catch (Exception e)
                    {
                        if (Debug)
                        {
                            Mbc!.StatusFile?.AddMsg(MsgLevel.WARNING, "Communication problem during ADC measurement");
                        }

                        if (i == NumRepeat)
                        {
                            throw;
                        }
                    }
                }
            }

            return v;
        }

        public double ComputeVolts(ADS1115 gain, byte[] raw)
        {
            double fsRange = gain switch
            {
                ADS1115.GAIN_TWOTHIRDS_6_144 => 6.144,
                ADS1115.GAIN_ONE_4_096 => 4.096,
                ADS1115.GAIN_TWO_2_048 => 2.048,
                ADS1115.GAIN_FOUR_1_024 => 1.024,
                ADS1115.GAIN_EIGHT_0_512 => 0.512,
                ADS1115.GAIN_SIXTEEN_0_256 => 0.256,
                _ => throw new ArgumentOutOfRangeException(nameof(gain), gain, "Unsupported ADS1115 gain value.")
            };

            double v = ((raw[0] << 8) + raw[1]) * (fsRange / 32768);
            if (Debug)
            {
                Console.WriteLine($"raw = 0x{raw[0]:X} 0x{raw[1]:X}, v = {v} V");
            }
            return v;
        }
    }
}

