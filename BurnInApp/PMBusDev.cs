using System;
using System.Threading;

namespace BurnInApp
{
    /// <summary>
    /// PMBusDev implements the support of PMBus devices via an MBC. Tested with Vishay SiC450.
    /// Converted from the MATLAB class PMBusDev by Torsten Blochwitz Electronics &amp; Software for InfraSolid.
    /// </summary>
    public class PMBusDev : SMBusDev
    {
        // exponent of VOUT related values, expressed in ULINEAR16
        public sbyte ExpU16 { get; private set; } = -9;
        public bool Debug { get; set; } = false;

        public PMBusDev(MBC_TB mbc, int addr, int offset, int mpAddr, int cOn, int cOff)
            : base(mbc, addr, offset, mpAddr, cOn, cOff, true)
        {
        }

        public bool SetCLEAR_FAULTS()
        {
            return WriteBytes(0x03, Array.Empty<byte>());
        }

        public bool SetWRITE_PROTECT(byte v)
        {
            return WriteBytes(0x10, new[] { v });
        }

        public byte GetSTATUS_CML()
        {
            return ReadBytes(0x7E, 1)[0];
        }

        public void GetVOUT_MODE()
        {
            // reads the exponent of VOUT related values, expressed in ULINEAR16 representation
            byte vu = ReadBytes(0x20, 1)[0];
            int mode = vu >> 5;
            if (mode != 0)
            {
                throw new InvalidOperationException("PMBus device does not support ULINEAR16 format for Vout. This is not implemented!");
            }

            sbyte vi = (sbyte)(vu << 3);
            ExpU16 = (sbyte)(vi >> 3);

            if (Debug)
            {
                Console.WriteLine($"VOUT_MODE returned LINEAR16, exp = {ExpU16}");
            }
        }

        public ushort GetSTATUS_WORD()
        {
            return ReadWord(0x79);
        }

        public byte GetSTATUS_VOUT()
        {
            return ReadBytes(0x7A, 1)[0];
        }

        public byte GetSTATUS_INPUT()
        {
            return ReadBytes(0x7C, 1)[0];
        }

        public double GetREAD_VIN()
        {
            ushort v = ReadWord(0x88);
            return LINEAR11_2double(v);
        }

        public double GetREAD_IIN()
        {
            ushort v = ReadWord(0x89);
            return uLINEAR11_2double(v);
        }

        public double GetREAD_VOUT()
        {
            ushort v = ReadWord(0x8B);
            return LINEAR16_2double(v, ExpU16);
        }

        public double GetREAD_IOUT()
        {
            ushort v = ReadWord(0x8C);
            return uLINEAR11_2double(v);
        }

        public double GetREAD_TEMPERATURE()
        {
            ushort v = ReadWord(0x8D);
            return LINEAR11_2double(v);
        }

        public bool SetVIN_OV_FAULT_RESPONSE(byte v)
        {
            return WriteBytes(0x56, new[] { v });
        }

        public bool SetVIN_OV_FAULT_LIMIT(double v)
        {
            ushort ov = double2LINEAR11(v, -1);
            return WriteWord(0x55, ov);
        }

        public double GetVIN_OV_FAULT_LIMIT()
        {
            ushort v = ReadWord(0x55);
            return LINEAR11_2double(v);
        }

        public bool SetVIN_UV_WARN_LIMIT(double v)
        {
            // VIN_UV_FAULT_LIMIT is not supported by SiC450!
            ushort sv = double2LINEAR11(v, -1);
            return WriteWord(0x58, sv);
        }

        public bool SetVOUT_OV_FAULT_LIMIT(double v)
        {
            ushort sv = double2LINEAR16(v, ExpU16);
            return WriteWord(0x40, sv);
        }

        public double GetVOUT_OV_FAULT_LIMIT()
        {
            ushort v = ReadWord(0x40);
            return LINEAR16_2double(v, ExpU16);
        }

        public double GetVOUT_UV_FAULT_LIMIT()
        {
            ushort v = ReadWord(0x44);
            return LINEAR16_2double(v, ExpU16);
        }

        public bool SetVOUT_OV_WARN_LIMIT(double v)
        {
            ushort sv = double2LINEAR16(v, ExpU16);
            return WriteWord(0x42, sv);
        }

        public bool SetVOUT_UV_FAULT_LIMIT(double v)
        {
            ushort sv = double2LINEAR16(v, ExpU16);
            return WriteWord(0x44, sv);
        }

        public bool SetVOUT_UV_WARN_LIMIT(double v)
        {
            ushort sv = double2LINEAR16(v, ExpU16);
            return WriteWord(0x43, sv);
        }

        public bool SetVOUT_MARGIN_LOW(double v)
        {
            ushort sv = double2LINEAR16(v, ExpU16);
            return WriteWord(0x26, sv);
        }

        public bool SetVOUT_MARGIN_HIGH(double v)
        {
            ushort sv = double2LINEAR16(v, ExpU16);
            return WriteWord(0x25, sv);
        }

        public double GetVOUT_MARGIN_LOW()
        {
            ushort v = ReadWord(0x26);
            return LINEAR16_2double(v, ExpU16);
        }

        public double GetVOUT_MARGIN_HIGH()
        {
            ushort v = ReadWord(0x25);
            return LINEAR16_2double(v, ExpU16);
        }

        public double GetPOWER_GOOD_ON()
        {
            ushort v = ReadWord(0x5E);
            return LINEAR16_2double(v, ExpU16);
        }

        public bool SetPOWER_GOOD_ON(double v)
        {
            ushort sv = double2LINEAR16(v, ExpU16);
            return WriteWord(0x5E, sv);
        }

        public double GetPOWER_GOOD_OFF()
        {
            ushort v = ReadWord(0x5F);
            return LINEAR16_2double(v, ExpU16);
        }

        public bool SetPOWER_GOOD_OFF(double v)
        {
            ushort sv = double2LINEAR16(v, ExpU16);
            return WriteWord(0x5F, sv);
        }

        public double GetVOUT_UV_WARN_LIMIT()
        {
            ushort v = ReadWord(0x43);
            return LINEAR16_2double(v, ExpU16);
        }

        public double GetVOUT_OV_WARN_LIMIT()
        {
            ushort v = ReadWord(0x42);
            return LINEAR16_2double(v, ExpU16);
        }

        public bool SetVOUT_COMMAND(double v)
        {
            ushort sv = double2LINEAR16(v, ExpU16);
            return WriteWord(0x21, sv);
        }

        public double GetVOUT_COMMAND()
        {
            ushort v = ReadWord(0x21);
            return LINEAR16_2double(v, ExpU16);
        }

        public bool SetVOUT_SCALE_LOOP(ushort v)
        {
            return WriteWord(0x29, v);
        }

        public ushort GetVOUT_SCALE_LOOP()
        {
            return ReadWord(0x29);
        }

        public bool SetTON_DELAY(double v)
        {
            ushort f = double2LINEAR11(v, 0);
            return WriteWord(0x60, f);
        }

        public bool SetTON_RISE(double v)
        {
            ushort f = double2LINEAR11(v, 0);
            return WriteWord(0x61, f);
        }

        public double GetTON_RISE()
        {
            ushort v = ReadWord(0x61);
            return LINEAR11_2double(v);
        }

        public bool SetTON_MAX_FAULT_LIMIT(double v)
        {
            ushort f = double2LINEAR11(v, 0);
            return WriteWord(0x62, f);
        }

        public double GetTON_MAX_FAULT_LIMIT()
        {
            ushort v = ReadWord(0x62);
            return LINEAR11_2double(v);
        }

        public bool SetFREQUENCY_SWITCH(double v)
        {
            ushort f = double2LINEAR11(v, 0);
            return WriteWord(0x33, f);
        }

        public double GetFREQUENCY_SWITCH()
        {
            ushort f = ReadWord(0x33);
            return LINEAR11_2double(f);
        }

        public bool SetOPERATION(byte v)
        {
            return WriteBytes(0x01, new[] { v });
        }

        public byte GetOPERATION()
        {
            return ReadBytes(0x01, 1)[0];
        }

        public bool SetVOUT_UV_FAULT_RESPONSE(byte v)
        {
            return WriteBytes(0x45, new[] { v });
        }

        public byte GetVOUT_UV_FAULT_RESPONSE()
        {
            return ReadBytes(0x45, 1)[0];
        }

        public bool SetON_OFF_CONFIGURATION(byte v)
        {
            return WriteBytes(0x02, new[] { v });
        }

        public byte GetON_OFF_CONFIGURATION()
        {
            return ReadBytes(0x02, 1)[0];
        }

        public bool SetEEPROM_PASSWORD(byte[] v)
        {
            return BlockWriteBytes(0xDB, v);
        }

        public bool SetSTORE_USER_ALL()
        {
            return WriteBytes(0x15, Array.Empty<byte>());
        }

        public double ReadVOUT()
        {
            // TODO: not implemented, see PMBusDev.m
            return 0.0;
        }

        public double ReadVIN()
        {
            // TODO: not implemented, see PMBusDev.m
            return 0.0;
        }

        public bool SwitchPWR(bool v)
        {
            // TODO: Check VIN and status before switching
            byte msg = (byte)(v ? 0b10001000 : 0b00001000);
            if (Debug)
            {
                Console.WriteLine($"\nSwitch {(v ? "ON" : "OFF")}");
            }
            return SetOPERATION(msg);
        }

        public bool Init()
        {
            SetCLEAR_FAULTS();
            GetVOUT_MODE();
            return true;
        }

        /// <summary>
        /// Converts a double value to a LINEAR16 uint16 according to the PMBus specification.
        /// </summary>
        public ushort double2LINEAR16(double w, int exp)
        {
            return (ushort)(w / Math.Pow(2.0, exp));
        }

        /// <summary>
        /// Converts a 16 bit LINEAR16 uint16 value (according to PMBus specification) to double.
        /// </summary>
        public double LINEAR16_2double(ushort v, int exp)
        {
            return v * Math.Pow(2.0, exp);
        }

        /// <summary>
        /// Converts a 16 bit LINEAR11 int16 value (according to PMBus specification) to double.
        /// </summary>
        public double LINEAR11_2double(ushort v)
        {
            short raw = unchecked((short)v);
            double exp = raw >> 11;
            short m = (short)(raw << 5);
            m = (short)(m >> 5);
            return m * Math.Pow(2.0, exp);
        }

        /// <summary>
        /// Converts a 16 bit LINEAR11 uint16 value (according to PMBus specification) to double.
        /// </summary>
        public double uLINEAR11_2double(ushort v)
        {
            short raw = unchecked((short)v);
            double exp = raw >> 11;
            ushort m = (ushort)(v << 5);
            m = (ushort)(m >> 5);
            return m * Math.Pow(2.0, exp);
        }

        /// <summary>
        /// Converts a double value to a LINEAR11 uint16 according to the PMBus specification.
        /// </summary>
        public ushort double2LINEAR11(double w, int exp)
        {
            short v = (short)(exp << 11);
            ushort vBits = (ushort)(unchecked((ushort)v) & 0b1111100000000000);
            ushort m = (ushort)((ushort)(w / Math.Pow(2, exp)) & 0b0000011111111111);
            return (ushort)(vBits | m);
        }

        public int Test(int mode)
        {
            switch (mode)
            {
                case 0:
                    Console.WriteLine("Test: Switch Off");
                    SwitchPWR(false);
                    GetSTATUS_CML();
                    GetSTATUS_WORD();
                    GetSTATUS_VOUT();
                    GetSTATUS_INPUT();
                    Thread.Sleep(1000);
                    SwitchPWR(true);
                    GetSTATUS_CML();
                    GetSTATUS_WORD();
                    GetSTATUS_VOUT();
                    GetSTATUS_INPUT();
                    Thread.Sleep(5000);
                    SwitchPWR(false);
                    GetSTATUS_CML();
                    GetSTATUS_WORD();
                    GetSTATUS_VOUT();
                    GetSTATUS_INPUT();
                    break;
                default:
                    Console.WriteLine("No valid test");
                    break;
            }
            return 0;
        }
    }
}
