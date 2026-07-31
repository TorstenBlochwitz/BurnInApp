using System;

namespace BurnInApp
{
    /// <summary>
    /// DCDCConverterBoard: functions to deal with a DCDC Converter Version 2.0.
    /// Converted from the MATLAB class DCDCConverterBoard by Torsten Blochwitz Electronics &amp; Software for InfraSolid.
    /// </summary>
    public class DCDCConverterBoard
    {
        // two DC/DC converters, index 0 = VDC1, index 1 = VDC2
        public PMBusDev?[] SiC450 { get; } = new PMBusDev?[2];
        public MBC_TB? Mbc { get; private set; }
        public int Offset { get; private set; }
        public int MPAddr { get; }
        public byte COn { get; }
        public byte COff { get; }
        public bool Debug { get; set; } = false;
        public int Status { get; internal set; } = 0;
        public string LastErrorMsg { get; internal set; } = "";
        public string UUID { get; private set; } = "";
        public int VersionErrorReported { get; private set; } = 0;
        public int NChannels { get; private set; } = 0;

        public DCDCConverterBoard(int mpAddr, byte cOn, byte cOff)
        {
            Offset = 0;
            MPAddr = mpAddr;
            COn = cOn;
            COff = cOff;
        }

        public void SwitchOff()
        {
            if (Status != 0)
            {
                try
                {
                    SwitchVDC(1, 0);
                    SwitchVDC(2, 0);
                    SwitchStatusLED_DCDC(0);
                }
                catch
                {
                    // ignore, matching the MATLAB catch-all
                }
            }
        }

        public int Connect(MBC_TB mbc, int offset)
        {
            int ret = 0;
            Mbc = mbc;
            Offset = offset;
            // check software version of ATtiny
            try
            {
                Mbc.ResetI2C();
                byte[] ver = GetSWVersion();
                if (ver[0] < 2)
                {
                    LastErrorMsg = $"Cannot connect to DC/DC Converter: current software version ({ver[0]}.{ver[1]}.{ver[2]}) must be updated to at least version 2.0.0.";
                    VersionErrorReported = Math.Min(VersionErrorReported + 1, 10);
                    return ret;
                }
                else
                {
                    VersionErrorReported = 0;
                }
                Status = 0;
                // DC/DC Converter Board 2.0
                SiC450[0] = new PMBusDev(Mbc, 0x38, offset, MPAddr, COn, COff);
                SiC450[0]!.Init();
                SwitchVDC(1, 0);
                NChannels = 1;
                Status = 1;
                // A Board with at least one channel is connected
                ret = 1;
                // DC/DC Converter Board 2.0
                if (mbc.CheckI2CAddr(0x3A, Offset, 2))
                {
                    SiC450[1] = new PMBusDev(Mbc, 0x3A, offset, MPAddr, COn, COff);
                    SiC450[1]!.Init();
                    SwitchVDC(2, 0);
                    NChannels = 2;
                    // A Board with two channels is connected
                    ret = 2;
                }
                SwitchStatusLED_DCDC(1);
                UUID = GetUUIDString();
                Status = 1;
            }
            catch (Exception exc)
            {
                LastErrorMsg = exc.Message;
            }
            return ret;
        }

        public bool UpdateRefToMBC(MBC_TB mbc)
        {
            Mbc = mbc;
            for (int i = 0; i < 2; i++)
            {
                SiC450[i]?.UpdateRefToMBC(mbc);
            }
            return true;
        }

        public bool SwitchVDC(int vdc, int v)
        {
            if (vdc > NChannels)
            {
                return false;
            }
            using (new I2CMultiplexerPCA9542A(Mbc, Offset, MPAddr, COn, COff))
            {
                // switch ATtiny: 0-off, 1-on, 2-blink
                Mbc!.WriteBytesI2C(0x08, Offset, new byte[] { (byte)(127 + vdc), (byte)v });
                bool on = v == 1 || v == 2;
                // switch Sic450
                SiC450[vdc - 1]!.SwitchPWR(on);
            }
            return true;
        }

        public byte GetVDCSwitchStatus(int vdc)
        {
            if (vdc > NChannels)
            {
                return 0;
            }
            using (new I2CMultiplexerPCA9542A(Mbc, Offset, MPAddr, COn, COff))
            {
                return Mbc!.QueryBytesI2C(0x08, Offset, (uint)(127 + vdc), 1, 1)[0];
            }
        }

        public bool SetFrequDuty(double f, byte duty)
        {
            using (new I2CMultiplexerPCA9542A(Mbc, Offset, MPAddr, COn, COff))
            {
                Mbc!.WriteBytesI2C(0x08, Offset, new byte[] { 130, (byte)(f * 10), duty });
            }
            return true;
        }

        public bool SetFrequDutyBank(int n, double f, byte duty)
        {
            using (new I2CMultiplexerPCA9542A(Mbc, Offset, MPAddr, COn, COff))
            {
                Mbc!.WriteBytesI2C(0x08, Offset, new byte[] { (byte)(133 + n), (byte)(f * 10), duty });
            }
            return true;
        }

        public bool SwitchStatusLED_DCDC(int v)
        {
            using (new I2CMultiplexerPCA9542A(Mbc, Offset, MPAddr, COn, COff))
            {
                // switch ATtiny
                Mbc!.WriteBytesI2C(0x08, Offset, new byte[] { 131, (byte)v });
            }
            return true;
        }

        public bool SetSiC450_Defaults(int vdc)
        {
            if (vdc > NChannels)
            {
                return false;
            }
            var dev = SiC450[vdc - 1]!;
            if (Debug)
            {
                Console.WriteLine($">>> Set Defaults for VDC: {vdc}");
                byte val = dev.GetON_OFF_CONFIGURATION();
                Console.WriteLine($"ON_OFF_CONFIGURATION = 0x{val:X} (0b{Convert.ToString(val, 2)})");
                byte op = dev.GetOPERATION();
                Console.WriteLine($"OPERATION = 0x{op:X} (0b{Convert.ToString(op, 2)})");
                double vout = dev.GetVOUT_COMMAND();
                Console.WriteLine($"VOUT = {vout:F6}");
            }
            dev.SetCLEAR_FAULTS();
            // allow writing to all registers
            dev.SetWRITE_PROTECT(0b00000000);
            // OFF
            dev.SetOPERATION(0x08);
            // react on EN pin and OPERATATION command
            dev.SetON_OFF_CONFIGURATION(0b00011111);
            // tested for best stability, lowest ripple, highest efficiency
            dev.SetFREQUENCY_SWITCH(1000);

            // set to recommended value for VOUT = 5 V, is kept constant according to Vishay support
            // VOUT_OV protection does not work if VOUT_SCALE_LOOP is adapted to VOUT
            dev.SetVOUT_SCALE_LOOP(0xE802);

            // Switch off reaction on VIN Over Voltage
            dev.SetVIN_OV_FAULT_RESPONSE(0);

            dev.SetVIN_OV_FAULT_LIMIT(24);
            dev.SetVIN_UV_WARN_LIMIT(8);

            dev.SetVOUT_OV_FAULT_LIMIT(5.5);
            dev.SetVOUT_OV_WARN_LIMIT(5.4);

            dev.SetVOUT_UV_FAULT_LIMIT(1.6);
            dev.SetVOUT_UV_WARN_LIMIT(1.7);

            dev.SetVOUT_UV_FAULT_RESPONSE(0b00000000);

            dev.SetVOUT_MARGIN_LOW(1.6);
            dev.SetVOUT_MARGIN_HIGH(5.4);

            dev.SetPOWER_GOOD_ON(1.6);
            dev.SetPOWER_GOOD_OFF(1.7);

            dev.SetTON_RISE(10);
            dev.SetTON_MAX_FAULT_LIMIT(100);

            dev.SetCLEAR_FAULTS();

            dev.SetVOUT_COMMAND(3.0);

            // TODO: check status
            return true;
        }

        public bool SetSiC450_StoreDefaults(int vdc)
        {
            if (vdc > NChannels)
            {
                return false;
            }
            var dev = SiC450[vdc - 1]!;
            dev.SetWRITE_PROTECT(0x00);
            dev.SetEEPROM_PASSWORD(new byte[] { 0x12, 0x34 });
            dev.SetSTORE_USER_ALL();
            // TODO: check status
            return true;
        }

        public bool SetSiC450_Voltage(int vdc, double v)
        {
            if (vdc > NChannels)
            {
                return false;
            }
            var dev = SiC450[vdc - 1]!;
            // sets VOUT of VDC, adapts VOUT_SCALE_LOOP, VOUT_OV_FAULT_LIMIT and VOUT_UV_FAULT_LIMIT
            ushort scale = 0xE802;
            double voutUvF = 1.6;
            double voutOvF = 5.5;
            double voutUvW = 1.5;
            double voutOvW = 5.4;
            double pgoodOn = 0.3;
            double pgoodOff = 0.28;
            if (v > 5.5)
            {
                v = 5.5;
            }
            if (v < 1.8)
            {
                scale = 0xE804;
                voutUvF = 0.28;
                voutOvF = 3.6;
                voutUvW = 0.3;
                voutOvW = 3.5;
                pgoodOn = 0.3;
                pgoodOff = 0.28;
            }
            bool on = false;
            if (scale != dev.GetVOUT_SCALE_LOOP())
            {
                byte op = dev.GetOPERATION();
                on = (op & 0x80) != 0;
                if (on)
                {
                    // switch off in case VOUT_SCALE_LOOP must be set to new values
                    // TODO: check if really necessary: 2024-02-02: Yes, if
                    // the change is done downwards with certain loads,
                    // sometimes oscilations in VDC occur
                    dev.SetOPERATION(0b00001000);
                }
                dev.SetVOUT_SCALE_LOOP(scale);
                dev.SetVOUT_UV_WARN_LIMIT(voutUvW);
                dev.SetVOUT_UV_FAULT_LIMIT(voutUvF);
                dev.SetVOUT_OV_WARN_LIMIT(voutOvW);
                dev.SetVOUT_OV_FAULT_LIMIT(voutOvF);
                dev.SetVOUT_MARGIN_LOW(voutUvF);
                dev.SetVOUT_MARGIN_HIGH(voutOvF);
                dev.SetPOWER_GOOD_ON(pgoodOn);
                dev.SetPOWER_GOOD_OFF(pgoodOff);
            }
            dev.SetVOUT_COMMAND(v);
            if (on)
            {
                // ON
                dev.SetOPERATION(0b10001000);
            }
            return true;
        }

        public byte[] GetUUID()
        {
            var uuid = new byte[16];
            using (new I2CMultiplexerPCA9542A(Mbc, Offset, MPAddr, COn, COff))
            {
                for (int i = 0; i < 16; i++)
                {
                    uuid[i] = Mbc!.QueryBytesI2C(0x08, Offset, (uint)(148 + i), 1, 1)[0];
                }
            }
            return uuid;
        }

        public bool SetUUID(byte[] uuid)
        {
            bool ret = false;
            using (new I2CMultiplexerPCA9542A(Mbc, Offset, MPAddr, COn, COff))
            {
                try
                {
                    for (int i = 0; i < 16; i++)
                    {
                        Mbc!.WriteBytesI2C(0x08, Offset, new byte[] { (byte)(148 + i), uuid[i] });
                    }
                    ret = true;
                }
                catch (Exception e)
                {
                    Console.WriteLine($"Something went wrong writing UUID. Check Mainboard!({e.Message}).");
                }
            }
            return ret;
        }

        public string GetUUIDString()
        {
            var sb = new System.Text.StringBuilder();
            byte[] uuid = GetUUID();
            for (int i = 0; i < 16; i++)
            {
                sb.Append(uuid[i].ToString("X2"));
                int oneBased = i + 1;
                if (oneBased == 4 || oneBased == 6 || oneBased == 8 || oneBased == 10)
                {
                    sb.Append('-');
                }
            }
            return sb.ToString();
        }

        public bool SetUUIDString(string str)
        {
            var uuid = new byte[16];
            string cleaned = str.Replace("-", string.Empty);
            if (cleaned.Length == 32)
            {
                for (int i = 0; i < 16; i++)
                {
                    uuid[i] = Convert.ToByte(cleaned.Substring(2 * i, 2), 16);
                }
                return SetUUID(uuid);
            }
            return false;
        }

        public byte[] GetSWVersion()
        {
            using (new I2CMultiplexerPCA9542A(Mbc, Offset, MPAddr, COn, COff))
            {
                return Mbc!.QueryBytesI2C(0x08, Offset, 255, 1, 3);
            }
        }

        public string GetSWVersionString()
        {
            try
            {
                byte[] ver = GetSWVersion();
                return $"{ver[0]}.{ver[1]}.{ver[2]}";
            }
            catch
            {
                return "???";
            }
        }

        public bool SetTimer(ushort t)
        {
            using (new I2CMultiplexerPCA9542A(Mbc, Offset, MPAddr, COn, COff))
            {
                return Mbc!.WriteBytesI2C(0x08, Offset, new byte[] { 128 + 4, (byte)(t % 256), (byte)(t >> 8) });
            }
        }

        public ushort GetTimer()
        {
            using (new I2CMultiplexerPCA9542A(Mbc, Offset, MPAddr, COn, COff))
            {
                byte[] bytes = Mbc!.QueryBytesI2C(0x08, Offset, 128 + 4, 1, 2);
                return (ushort)(bytes[1] * 256 + bytes[0]);
            }
        }

        public bool SetATtinyStatus(byte s)
        {
            using (new I2CMultiplexerPCA9542A(Mbc, Offset, MPAddr, COn, COff))
            {
                return Mbc!.WriteBytesI2C(0x08, Offset, new byte[] { 128 + 5, s });
            }
        }

        public byte GetATtinyStatus()
        {
            using (new I2CMultiplexerPCA9542A(Mbc, Offset, MPAddr, COn, COff))
            {
                return Mbc!.QueryBytesI2C(0x08, Offset, 128 + 5, 1, 1)[0];
            }
        }

        public void SwitchOn(double vdc1, double vdc2, double f1, double f2, byte dutyCycle1, byte dutyCycle2, ushort duration)
        {
            int mode1 = 1;
            int mode2 = 1;
            if (f1 > 0)
            {
                SetFrequDutyBank(1, f1, dutyCycle1);
                mode1 = 2;
            }
            if (f2 > 0)
            {
                SetFrequDutyBank(2, f2, dutyCycle2);
                mode2 = 2;
            }
            if (vdc1 > 0.0)
            {
                SetSiC450_Voltage(1, vdc1);
            }
            else
            {
                // Do not switch on, if voltage is 0
                mode1 = 0;
            }
            if (NChannels > 1)
            {
                if (vdc2 > 0)
                {
                    SetSiC450_Voltage(2, vdc2);
                }
                else
                {
                    // Do not switch on, if voltage is 0
                    mode2 = 0;
                }
            }
            SetTimer(duration);
            SwitchVDC(1, mode1);
            SwitchVDC(2, mode2);
        }

        public bool CheckSiC450()
        {
            // fix for issue #12: sometimes a timeout happens
            // we check 10 times and return after 1st success
            for (int i = 0; i < 10; i++)
            {
                try
                {
                    SiC450[0]!.GetSTATUS_WORD();
                    if (NChannels > 1)
                    {
                        SiC450[1]!.GetSTATUS_WORD();
                    }
                    // TODO: check status word!
                    return true;
                }
                catch (Exception exc)
                {
                    LastErrorMsg = exc.Message;
                }
            }
            return false;
        }
    }
}
