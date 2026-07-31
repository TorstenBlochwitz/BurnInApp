using System;
using System.Text;

namespace BurnInApp
{
    /// <summary>
    /// EEPROM_M24C02 for storing a UUID and other data in the BurnIn application.
    /// Converted from the MATLAB class EEPROM_M24C02 by Torsten Blochwitz Electronics &amp; Software for InfraSolid.
    /// </summary>
    public class EEPROM_M24C02
    {
        public MBC_TB? Mbc { get; private set; }
        public int Address { get; }
        public int Offset { get; }
        public bool Debug { get; set; } = true;
        public int MPAddr { get; } = 0xE0;
        public byte COn { get; }
        public byte COff { get; }

        // TODO: handle offset for EEPROM correctly!
        public EEPROM_M24C02(MBC_TB? mbc, int address, int offset, int mpAddr, byte cOn, byte cOff)
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

        public byte[] GetUUID()
        {
            var uuid = new byte[16];
            using (new I2CMultiplexerPCA9542A(Mbc, Offset, MPAddr, COn, COff))
            {
                for (int i = 0; i < 16; i++)
                {
                    byte[] v = Mbc!.QueryBytesI2C(Address, Offset, (uint)i, 1, 1);
                    uuid[i] = v[0];
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
                        Mbc!.WriteBytesI2C(Address, Offset, new byte[] { (byte)i, uuid[i] });
                    }
                    ret = true;
                }
                catch (Exception e)
                {
                    Console.WriteLine($"Something went wrong writing to EEPROM. Check write access jumper!!({e.Message}).");
                }
            }
            return ret;
        }

        public string GetUUIDString()
        {
            var sb = new StringBuilder();
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
    }
}
