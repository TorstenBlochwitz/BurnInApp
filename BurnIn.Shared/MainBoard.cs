using System;
using System.Threading;

namespace BurnIn.Shared
{
    /// <summary>
    /// MainBoard: functions to deal with a BurnIn Main Board.
    /// Converted from the MATLAB class MainBoard by Torsten Blochwitz Electronics &amp; Software for InfraSolid.
    /// </summary>
    public class MainBoard
    {
        public MBC_TB? Mbc { get; private set; }
        public int Offset { get; private set; }
        public bool Debug { get; set; } = false;
        public int Status { get; private set; } = 0;
        public string LastErrorMsg { get; private set; } = "";

        // Address of I2C Multiplexer (set to 0 if there is no)
        public int MPAddr { get; }
        // Command to switch channel on
        public byte COn { get; }
        // Command to switch channel off
        public byte COff { get; }

        public ADC_ADS1115? Adc { get; private set; }
        public EEPROM_M24C02? EEPROM { get; private set; }
        public TempSensor_TMP1075?[] TempSensor { get; } = new TempSensor_TMP1075?[3];

        public double RShunt { get; set; } = 0.82;
        public double PShuntMax { get; set; } = 0.4;
        public string UUID { get; private set; } = "";

        public double BrightnessPosLEDs { get; set; } = 20; // in percent
        public double BrightnessStatusLEDs { get; set; } = 20;

        // color of status LEDs
        public double[] RgbLEDstatus1 { get; private set; } = { 0.0, 0.0, 0.0 };
        public double[] RgbLEDstatus2 { get; private set; } = { 0.0, 0.0, 0.0 };
        public double[] RgbLEDstatus3 { get; private set; } = { 0.0, 0.0, 0.0 };

        // D1 at P17 of D1 (PCF8575DWR)
        public bool StatusLED { get; private set; } = false;

        // reading the status of PCF8575DWR is not safe because the pins
        // switch to input mode. For that reason, we store the status here:
        public byte[] StatusPCF8575DWR { get; private set; } = { 0xFF, 0xFF };

        public MainBoardKind MainBoardKindValue { get; private set; }

        public MainBoard(int mpAddr, byte cOn, byte cOff)
        {
            Offset = 0;
            MPAddr = mpAddr;
            COn = cOn;
            COff = cOff;
            LastErrorMsg = "";
        }

        public int Connect(MBC_TB mbc, int offset, MainBoardKind mainBoardKind)
        {
            Mbc = mbc;
            Offset = offset;
            MainBoardKindValue = mainBoardKind;
            try
            {
                Status = 0;
                // Reset I2C (due to hot plug, something might have happened!)
                Mbc.ResetI2C();
                // check existance
                SwitchStatusLED(1);
                // switch off analog multiplexer
                SetMUX(-1);
                Adc = new ADC_ADS1115(Mbc, 0x90, offset, MPAddr, COn, COff);
                EEPROM = new EEPROM_M24C02(Mbc, 0xA0, offset, MPAddr, COn, COff);
                TempSensor[0] = new TempSensor_TMP1075(Mbc, 0x94, Offset, MPAddr, COn, COff);
                TempSensor[1] = new TempSensor_TMP1075(Mbc, 0x98, Offset, MPAddr, COn, COff);
                TempSensor[2] = new TempSensor_TMP1075(Mbc, 0x9C, Offset, MPAddr, COn, COff);

                UUID = EEPROM.GetUUIDString();

                Status = 1;
            }
            catch (Exception exc)
            {
                LastErrorMsg = exc.Message;
            }
            return Status;
        }

        public bool UpdateRefToMBC(MBC_TB mbc)
        {
            Mbc = mbc;
            Adc?.UpdateRefToMBC(mbc);
            EEPROM?.UpdateRefToMBC(mbc);
            for (int i = 0; i < 3; i++)
            {
                TempSensor[i]?.UpdateRefToMBC(mbc);
            }
            return true;
        }

        public bool CheckMainBoard()
        {
            bool status = false;
            try
            {
                SetMUX(-1);
                status = true;
            }
            catch (Exception exc)
            {
                LastErrorMsg = exc.Message;
            }
            return status;
        }

        public int SwitchStatusLED(int v)
        {
            using var i2cMulti = new I2CMultiplexerPCA9542A(Mbc, Offset, MPAddr, COn, COff);
            int ret = 0;
            // Current status of PCF8575DWR
            byte[] bytes = (byte[])StatusPCF8575DWR.Clone();
            if (Debug)
            {
                int val = bytes[0] * 256 + bytes[1];
                Console.WriteLine($"cur MUX = 0x{val:X} (0b{Convert.ToString(val, 2)})");
            }
            // set bit 8, which correlates to P17
            if (v == 1)
            {
                bytes[1] = BitSet(bytes[1], 8, false);
                if (Debug)
                {
                    Console.WriteLine("LED: On");
                }
                ret = 1;
            }
            else
            {
                bytes[1] = BitSet(bytes[1], 8, true);
                if (Debug)
                {
                    Console.WriteLine("LED: Off");
                }
            }
            Mbc!.WriteBytesI2CCheck(0x40, Offset, bytes, new byte[] { 0xFF, 0xFF });
            StatusLED = v > 0;
            StatusPCF8575DWR = bytes;
            return ret;
        }

        public int SetMUX(int pos)
        {
            using var i2cMulti = new I2CMultiplexerPCA9542A(Mbc, Offset, MPAddr, COn, COff);
            var bytes = new byte[2];
            if (pos < 0)
            {
                // disable all MUX channels
                // set all bits except LED (P17) to 1
                bytes[0] = 0xFF;
                bytes[1] = BitSet(0xFF, 8, !StatusLED);
                if (Debug)
                {
                    int val = bytes[1] * 256 + bytes[0];
                    Console.WriteLine($"bytes = 0x{val:X} (0b{Convert.ToString(val, 2)})");
                }
            }
            else
            {
                // set A0..A7 (P00..P07), bits 9..16
                bytes[0] = (byte)pos;
                // enable EN_GND (P10)
                bytes[1] = BitSet(0xFF, 1, false);
                // keep LED (P17)
                bytes[1] = BitSet(bytes[1], 8, !StatusLED);
                if (Debug)
                {
                    int val = bytes[1] * 256 + bytes[0];
                    Console.WriteLine($"bytes = 0x{val:X} (0b{Convert.ToString(val, 2)})");
                }
            }
            Mbc!.WriteBytesI2CCheck(0x40, Offset, bytes, new byte[] { 0xFF, 0xFF });
            // store the values in status after sending to ensure it is the
            // correct value in case an exception was thrown
            StatusPCF8575DWR = bytes;
            return 1;
        }

        public int WriteMuxSafely(byte[] bytes)
        {
            int ret = 0;
            const int attempts = 10; // max. number of attempts
            for (int i = 1; i <= attempts; i++)
            {
                Mbc!.WriteBytesI2C(0x40, Offset, bytes);
                // check read stability
                byte[] read1 = Mbc.ReadBytesI2C(0x40, Offset, 2);
                byte[] read2 = Mbc.ReadBytesI2C(0x40, Offset, 2);
                if (!ByteArraysEqual(read1, read2))
                {
                    continue;
                }
                // check returned value
                if (ByteArraysEqual(read2, bytes))
                {
                    ret = 1;
                    if (i > 1)
                    {
                        Console.WriteLine("setMux retried");
                    }
                    break;
                }
            }
            if (ret == 0)
            {
                Console.WriteLine("Problem setting MUX");
            }
            return ret;
        }

        public int SwitchRGBLED(int index, double r, double g, double b, bool switchOffLEDs, bool setLEDs)
        {
            using var i2cMulti = new I2CMultiplexerPCA9542A(Mbc, Offset, MPAddr, COn, COff);
            index = Math.Max(1, index);
            if (index == 26)
            {
                index = 125;
            }

            // keep status RGB LEDs at current color
            double[][] rgb = { RgbLEDstatus1, RgbLEDstatus2, RgbLEDstatus3 };
            if (switchOffLEDs)
            {
                int iStatusLEDstart = MainBoardKindValue > MainBoardKind.FullBoardWithATtiny ? 59 : 119;
                for (int i = 0; i < 3; i++)
                {
                    Mbc!.WriteBytesI2C(0x08, Offset, new byte[]
                    {
                        (byte)(iStatusLEDstart + i + 1),
                        (byte)(rgb[i][0] * BrightnessStatusLEDs / 100),
                        (byte)(rgb[i][1] * BrightnessStatusLEDs / 100),
                        (byte)(rgb[i][2] * BrightnessStatusLEDs / 100),
                        (byte)(switchOffLEDs ? 1 : 0),
                        0
                    });
                    switchOffLEDs = false;
                }
            }
            // during testing, sometimes the MBC returned an error because of
            // missing I2C ACK signal. Let's try again maximum 10 times
            Mbc!.WriteBytesI2C(0x08, Offset, new byte[]
            {
                (byte)(index - 1),
                (byte)(r * BrightnessPosLEDs / 100),
                (byte)(g * BrightnessPosLEDs / 100),
                (byte)(b * BrightnessPosLEDs / 100),
                (byte)(switchOffLEDs ? 1 : 0),
                (byte)(setLEDs ? 1 : 0)
            });
            if (!OperatingSystem.IsWindows())
            {
                Thread.Sleep(100);
            }
            return 1;
        }

        public void SwitchRGBLEDs(bool[] bSwitch, double r, double g, double b)
        {
            int last = 0;
            // Backwards should go faster
            for (int i = bSwitch.Length; i >= 1; i--)
            {
                if (bSwitch[i - 1])
                {
                    last = i;
                    break;
                }
            }
            for (int i = 1; i <= last; i++)
            {
                if (bSwitch[i - 1])
                {
                    SwitchRGBLED(i, r, g, b, false, last == i);
                }
            }
        }

        public void SwitchOff(bool complete = true)
        {
            try
            {
                SetMUX(-1);
                SwitchStatusLED(0);
                if (complete)
                {
                    SwitchRGBLED(0, 0, 0, 0, true, true);
                }
            }
            catch
            {
                // ignore, matching the MATLAB catch-all
            }
        }

        public void SwitchOn()
        {
            SwitchStatusLED(1);
        }

        public double GetVMaxShortCircuit()
        {
            // returns maximum voltage for checking for short circuits
            return Math.Sqrt(RShunt * PShuntMax);
        }

        public void SetStatusRGBLEDs(double[] rgbLEDstatus1, double[] rgbLEDstatus2, double[] rgbLEDstatus3)
        {
            bool updateNeeded = false;
            if (!ArraysEqual(RgbLEDstatus1, rgbLEDstatus1))
            {
                updateNeeded = true;
                RgbLEDstatus1 = rgbLEDstatus1;
            }
            if (!ArraysEqual(RgbLEDstatus2, rgbLEDstatus2))
            {
                updateNeeded = true;
                RgbLEDstatus2 = rgbLEDstatus2;
            }
            if (!ArraysEqual(RgbLEDstatus3, rgbLEDstatus3))
            {
                updateNeeded = true;
                RgbLEDstatus3 = rgbLEDstatus3;
            }
            if (updateNeeded)
            {
                int iStatusLEDstart = MainBoardKindValue > MainBoardKind.FullBoardWithATtiny ? 60 : 120;
                // don't change other RGB LEDs
                SwitchRGBLED(iStatusLEDstart + 1, rgbLEDstatus1[0], rgbLEDstatus1[1], rgbLEDstatus1[2], false, false);
                SwitchRGBLED(iStatusLEDstart + 2, rgbLEDstatus2[0], rgbLEDstatus2[1], rgbLEDstatus2[2], false, false);
                SwitchRGBLED(iStatusLEDstart + 3, rgbLEDstatus3[0], rgbLEDstatus3[1], rgbLEDstatus3[2], false, true);
            }
        }

        // Sets or clears bit "bitPos1Based" (1 = LSB, 8 = MSB) of value, matching MATLAB's bitset semantics.
        private static byte BitSet(byte value, int bitPos1Based, bool set)
        {
            int mask = 1 << (bitPos1Based - 1);
            return set ? (byte)(value | mask) : (byte)(value & ~mask);
        }

        private static bool ByteArraysEqual(byte[] a, byte[] b)
        {
            if (a.Length != b.Length)
            {
                return false;
            }
            for (int i = 0; i < a.Length; i++)
            {
                if (a[i] != b[i])
                {
                    return false;
                }
            }
            return true;
        }

        private static bool ArraysEqual(double[] a, double[] b)
        {
            if (a.Length != b.Length)
            {
                return false;
            }
            for (int i = 0; i < a.Length; i++)
            {
                if (a[i] != b[i])
                {
                    return false;
                }
            }
            return true;
        }
    }
}

