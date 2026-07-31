using System;

namespace BurnInApp
{
    /// <summary>
    /// Helper to compute the n-th serial number following a base serial number.
    /// Converted from the MATLAB function getSNr.m by Torsten Blochwitz Electronics &amp; Software for InfraSolid
    /// </summary>
    public static class SerialNumberHelper
    {
        /// <summary>
        /// Checks baseSNr as string and returns the n-th serial number after baseSNr.
        /// </summary>
        /// <param name="baseSNr">A 6-character serial number, format: 2 letters + 4 digit number (e.g. "AB0001")</param>
        /// <param name="n">1-based index; n=1 returns baseSNr itself</param>
        public static (bool ret, string str) GetSNr(string baseSNr, int n)
        {
            if (n > 0)
            {
                n -= 1;
            }

            string snr = (baseSNr ?? string.Empty).ToUpperInvariant();
            if (snr.Length != 6)
            {
                return (false, "");
            }

            char pr1 = snr[0];
            char pr2 = snr[1];
            if (pr1 < 'A' || pr1 > 'Z' || pr2 < 'A' || pr2 > 'Z')
            {
                return (false, "");
            }

            if (!int.TryParse(snr.Substring(2, 4), out int po) || po == 0)
            {
                return (false, "");
            }

            if (n == 0)
            {
                return (true, snr);
            }

            long npo;
            long o1;
            if (po + n == 9999)
            {
                // special case to exclude 0000
                npo = 9999;
                o1 = 0;
            }
            else
            {
                npo = (po + n) % 9999;
                o1 = (po + n) / 9999;
            }

            long npr2 = 'A' + (pr2 + o1 - 'A') % 26;
            long o2 = (pr2 + o1 - 'A') / 26;
            long npr1 = 'A' + (pr1 + o2 - 'A') % 26;

            string str = $"{(char)npr1}{(char)npr2}{npo:D4}";
            return (true, str);
        }
    }
}
