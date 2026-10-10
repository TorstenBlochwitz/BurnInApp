using System;

namespace BurnIn.Shared
{
    /// <summary>
    /// I2CMultiplexerPCA9542A: simplifies safe handling of I2C channel switching.
    /// The channel is switched on in the constructor and switched off when the instance is disposed.
    /// This makes sure that even in case of an exception, the channel is switched off - use it with
    /// a "using" statement (or block) to get the same deterministic behavior as the MATLAB
    /// constructor/destructor pair.
    /// Converted from the MATLAB class I2CMultiplexerPCA9542A by Torsten Blochwitz Electronics &amp; Software for InfraSolid.
    /// </summary>
    public class I2CMultiplexerPCA9542A : IDisposable
    {
        public MBC_TB? Mbc { get; }
        public int Offset { get; }
        public bool Debug { get; set; } = true;
        public int MPAddr { get; } = 0xE0;
        public byte COn { get; }
        public byte COff { get; }

        private bool _disposed;

        public I2CMultiplexerPCA9542A(MBC_TB? mbc, int offset, int mpAddr, byte cOn, byte cOff)
        {
            Mbc = mbc;
            Offset = offset;
            MPAddr = mpAddr;
            COn = cOn;
            COff = cOff;

            // switch channel on in the constructor
            if (Mbc != null && MPAddr != 0)
            {
                Mbc.WriteBytesI2C(MPAddr, Offset, new[] { COn });
            }
        }

        public void Dispose()
        {
            if (_disposed)
            {
                return;
            }
            _disposed = true;

            // switch channel off in the destructor
            try
            {
                if (Mbc != null && MPAddr != 0)
                {
                    Mbc.WriteBytesI2C(MPAddr, Offset, new[] { COff });
                }
            }
            catch
            {
                // ignore, matching the MATLAB delete() method
            }

            GC.SuppressFinalize(this);
        }
    }
}

