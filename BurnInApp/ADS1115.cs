using System;

namespace BurnInApp
{
    /// <summary>
    /// ADS1115 register/configuration constants and gain settings.
    /// Converted from the MATLAB class ADS1115 by Torsten Blochwitz Electronics &amp; Software for InfraSolid.
    /// </summary>
    public enum ADS1115 : ushort
    {
        GAIN_TWOTHIRDS_6_144 = 0x0000, // ADS1X15_REG_CONFIG_PGA_6_144V
        GAIN_ONE_4_096 = 0x0200,       // ADS1X15_REG_CONFIG_PGA_4_096V
        GAIN_TWO_2_048 = 0x0400,       // ADS1X15_REG_CONFIG_PGA_2_048V
        GAIN_FOUR_1_024 = 0x0600,      // ADS1X15_REG_CONFIG_PGA_1_024V
        GAIN_EIGHT_0_512 = 0x0800,     // ADS1X15_REG_CONFIG_PGA_0_512V
        GAIN_SIXTEEN_0_256 = 0x0A00,   // ADS1X15_REG_CONFIG_PGA_0_256V

        ADS1X15_REG_CONFIG_MODE_CONTIN = 0x0000, // Continuous conversion mode
        ADS1X15_REG_CONFIG_MODE_SINGLE = 0x0100, // Power-down single-shot mode (default)

        CONFIG_MUX_DIFF_0_1 = 0x0000, // Differential P = AIN0, N = AIN1 (default)
        CONFIG_MUX_DIFF_0_3 = 0x1000, // Differential P = AIN0, N = AIN3
        CONFIG_MUX_DIFF_1_3 = 0x2000, // Differential P = AIN1, N = AIN3
        CONFIG_MUX_DIFF_2_3 = 0x3000, // Differential P = AIN2, N = AIN3
        // not yet used
        CONFIG_MUX_SINGLE_0 = 0x4000, // Single-ended AIN0
        CONFIG_MUX_SINGLE_1 = 0x5000, // Single-ended AIN1
        CONFIG_MUX_SINGLE_2 = 0x6000, // Single-ended AIN2
        CONFIG_MUX_SINGLE_3 = 0x7000  // Single-ended AIN3
    }
}
