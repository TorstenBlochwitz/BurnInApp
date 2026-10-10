using System;

namespace BurnIn.Shared
{
    /// <summary>
    /// MBC_TB Construct a MBC_TB object.
    /// Converted from MATLAB class by Torsten Blochwitz Electronics & Software for InfraSolid
    /// </summary>
    public class MBC_TB : MBC_USB_TCP
    {
        public MBC_TB(params object[] args) : base(args)
        {
            // We have to distinguish between an MBC which communicates via
            // COM and the Ethernet MBCs
            I2CAddresses = new System.Collections.Generic.List<I2CAddressMapping>
            {
                new I2CAddressMapping(0x08, I2CAddrProp.NORMAL, I2CAddrProp.NORMAL), // µC ATtiny84A: U3
                new I2CAddressMapping(0x38, I2CAddrProp.NORMAL, I2CAddrProp.NORMAL), // DC/DC Converter for VDC1 SiC450: U1
                new I2CAddressMapping(0x3A, I2CAddrProp.NORMAL, I2CAddrProp.NORMAL), // DC/DC Converter for VDC2 SiC450: U2
                new I2CAddressMapping(0x40, I2CAddrProp.NORMAL, I2CAddrProp.NORMAL), // 16 bit I2C to GPIO PCF8575DWR: IC2
                new I2CAddressMapping(0x90, I2CAddrProp.NORMAL, I2CAddrProp.NORMAL), // ADC ADS1115: IC2
                new I2CAddressMapping(0x92, I2CAddrProp.NORMAL, I2CAddrProp.NORMAL), // ? exists also with deactivated I2C Multiplexer
                new I2CAddressMapping(0x94, I2CAddrProp.NORMAL, I2CAddrProp.NORMAL), // Temperature Sensor TMP1075DGKR: IC13
                new I2CAddressMapping(0x98, I2CAddrProp.NORMAL, I2CAddrProp.NORMAL), // Temperature Sensor TMP1075DGKR: IC10
                new I2CAddressMapping(0x9C, I2CAddrProp.NORMAL, I2CAddrProp.NORMAL), // Temperature Sensor TMP1075DGKR: IC11
                new I2CAddressMapping(0xA0, I2CAddrProp.NORMAL, I2CAddrProp.NORMAL), // EEPROM M24C02 (Memory access): IC3
                new I2CAddressMapping(0xB0, I2CAddrProp.NORMAL, I2CAddrProp.NORMAL), // EEPROM M24C02 (Identification page access): IC3
                new I2CAddressMapping(0xE0, I2CAddrProp.USE_OFFSET, I2CAddrProp.NORMAL), // I2C Multiplexer PCA9542APW: IC9
            };

            Timeout = 2;
            AddrOffset = 0;
            CloseFlag = false;
            DUTi2cEnable = false;
            Version = GetVersion();
        }

        // check for response at addr, offset
        public bool CheckI2CAddr(int addr, int offset, int? nRepeat = null)
        {
            int repeatCount = nRepeat ?? NumRepeat;

            // check if MBC is still connected by asking for version
            GetVersion();

            SwitchI2C(0);

            var (i2cAddr, _) = AdaptAddr(addr, offset);
            string msg = $"IR_{i2cAddr:X2}001";

            for (int i = 0; i < repeatCount; i++)
            {
                try
                {
                    string resp = WriteMessage(msg, offset);
                    if (resp.Length != 3)
                    {
                        return true;
                    }
                }
                catch (Exception e)
                {
                    if (Debug)
                    {
                        string strAddr = offset == 0 ? $"0x{addr:X}" : $"0x{addr:X}, offset = {offset}";
                        StatusFile?.AddMsg(MsgLevel.WARNING,
                            $"{i + 1}. I2C communication problem in CheckI2CAddr: {e.Message}\naddr = {strAddr}, msg = {msg}\n");
                    }

                    if (i == repeatCount - 1)
                    {
                        return false;
                    }
                }
            }

            return false;
        }

        public void SetI2Cfrequency(int v)
        {
            string msg = v < 10 ? $"IS_0{v}" : $"IS_{v}";
            WriteSerial(msg);
        }

        // overwritten function of base class to repeat sending in case of
        // an error due to timing
        public override void SwitchI2C(int port)
        {
            // switch between internal and DUT port
            // 0: internal (control bus)
            // 1: DUT
            if (Mode == MBCModeEnum.I2C)
            {
                // not supported in version 2
                int dotIndex = Version.IndexOf('.', 1);
                if (dotIndex > 1 && int.TryParse(Version.Substring(1, dotIndex - 1), out int majorVersion) && majorVersion == 2)
                {
                    return;
                }

                if (!DUTi2cEnable)
                {
                    port = 0;
                }

                // set i2c to internal
                string msg = port != 0 ? "PS_E21" : "PS_E20";

                for (int i = 0; i < NumRepeat; i++)
                {
                    try
                    {
                        string resp = WriteSerial(msg);

                        if (!string.IsNullOrEmpty(resp))
                        {
                            HandleError(resp);
                        }
                        else
                        {
                            break;
                        }
                    }
                    catch (Exception e)
                    {
                        Console.WriteLine($"{i + 1}. I2C communication problem in SwitchI2C: {e.Message}\nmsg = {msg}");
                        if (i == NumRepeat - 1)
                        {
                            throw;
                        }
                    }
                }
            }
        }
    }
}

