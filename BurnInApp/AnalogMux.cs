using System;

namespace BurnInApp
{
    /// <summary>
    /// AnalogMux: simplifies safe handling of the analog multiplexer.
    /// Nothing is done in the constructor, but on disposal all analog channels are disabled.
    /// This makes sure that even in case of an exception, the channel is switched off.
    /// Use it with a "using" statement (or block) to get the same deterministic behavior as
    /// the MATLAB constructor/destructor pair.
    /// Converted from the MATLAB class AnalogMux by Torsten Blochwitz Electronics &amp; Software for InfraSolid.
    /// </summary>
    public class AnalogMux : IDisposable
    {
        public MainBoard MainBoard { get; }

        private bool _disposed;

        public AnalogMux(MainBoard mainBoard)
        {
            MainBoard = mainBoard;
        }

        public void Dispose()
        {
            if (_disposed)
            {
                return;
            }
            _disposed = true;

            // switch all channels off in the destructor
            try
            {
                MainBoard.SetMUX(-1);
            }
            catch
            {
                // ignore, matching the MATLAB delete() method
            }

            GC.SuppressFinalize(this);
        }
    }
}
