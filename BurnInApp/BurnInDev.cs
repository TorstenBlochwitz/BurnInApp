using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;

namespace BurnInApp
{
    /// <summary>
    /// BurnInDev: interface to a BurnIn Device consisting of a DCDCConverterBoard
    /// (with or without an LED Board) and a MainBoard.
    /// I2C addresses:
    ///   0x08: uC ATtiny84A: U3
    ///   0x38: DC/DC Converter for VDC1 SiC450: U1
    ///   0x3A: DC/DC Converter for VDC2 SiC450: U2
    ///   0x40: 16 bit I2C to GPIO PCF8575DWR: IC2
    ///   0x90: ADC ADS1115: IC2
    ///   0x92: ? exists also with deactivated I2C Multiplexer
    ///   0x94: Temperature Sensor TMP1075DGKR: IC13
    ///   0x98: Temperature Sensor TMP1075DGKR: IC10
    ///   0x9C: Temperature Sensor TMP1075DGKR: IC11
    ///   0xA0: EEPROM M24C02 (Memory access): IC3
    ///   0xB0: EEPROM M24C02 (Identification page access): IC3
    ///   0xE0: I2C Multiplexer PCA9542APW: IC9
    /// Converted from the MATLAB class BurnInDev by Torsten Blochwitz Electronics &amp; Software for InfraSolid.
    /// </summary>
    public class BurnInDev
    {
        public MBC_TB? Mbc { get; private set; }
        public int Offset { get; private set; }
        // Address of I2C Multiplexer (set to 0 if there is no)
        public int MPAddr { get; } = 0xE0;
        // Command to switch channel on
        public byte COn { get; } = 0x04;
        // Command to switch channel off
        public byte COff { get; } = 0x00;
        public DCDCConverterBoard DCDCConv { get; }
        public MainBoard MainBoard { get; }
        // number of reported no DC/DC Converter Board error messages
        public int NoDCDCConverterErrorReported { get; private set; } = 0;
        public string LastErrorMessage { get; private set; } = "";

        public BurnInDev()
        {
            DCDCConv = new DCDCConverterBoard(MPAddr, COn, COff);
            MainBoard = new MainBoard(MPAddr, COn, COff);
        }

        public int ConnectBoards(MBC_TB mbc, int offset)
        {
            Mbc = mbc;
            Offset = offset;

            int ret = ConnectDCDCConverterBoard(mbc, offset);
            if (ret == 1)
            {
                ret = ConnectMainBoard();
            }
            return ret;
        }

        public int ConnectDCDCConverterBoard(MBC_TB mbc, int offset)
        {
            int ret = 0;
            Mbc = mbc;
            Offset = offset;

            // Is the I2C Multiplexer there?
            // TODO: Needs to be changed for final TCP/IP Version since there is no
            // I2C Multiplexer anymore
            if (mbc.CheckI2CAddr(MPAddr, offset))
            {
                NoDCDCConverterErrorReported = 0;
                ret = DCDCConv.Connect(mbc, offset);
                if (ret > 0)
                {
                    DCDCConv.SetSiC450_Defaults(1);
                    DCDCConv.Status = 1;
                    if (ret == 2)
                    {
                        DCDCConv.SetSiC450_Defaults(2);
                    }
                    // set ATtinyStatus to a value > 1 to signal it was connected
                    DCDCConv.SetATtinyStatus(2);
                }
            }
            else
            {
                DCDCConv.Status = ret > 0 ? 1 : 0;
                DCDCConv.LastErrorMsg = $"No DC/DC Converter with I2C offset {offset} connected to MBC!";
                NoDCDCConverterErrorReported = Math.Min(NoDCDCConverterErrorReported + 1, 10);
            }
            return ret;
        }

        public int ConnectMainBoard()
        {
            MainBoardKind mainBoardKind = DCDCConv.NChannels > 1
                ? MainBoardKind.FullBoardWithATtiny
                : MainBoardKind.HalfBoardWithATtiny;
            return MainBoard.Connect(Mbc!, Offset, mainBoardKind);
        }

        public bool SwitchOffI2CMultiplexer()
        {
            bool ret = false;
            if (MPAddr != 0)
            {
                try
                {
                    Mbc!.WriteBytesI2C(MPAddr, Offset, new[] { COff });
                    ret = true;
                }
                catch
                {
                    // ignore, matching the MATLAB catch-all
                }
            }
            return ret;
        }

        public bool UpdateRefToMBC(MBC_TB mbc)
        {
            Mbc = mbc;
            DCDCConv.UpdateRefToMBC(mbc);
            MainBoard.UpdateRefToMBC(mbc);
            return true;
        }

        public (bool status, double vdc) MeasureVDC(int i)
        {
            // Make sure the analog multiplexer is really switched off at the
            // end, even if an exception is thrown
            using var analogMux = new AnalogMux(MainBoard);
            bool status = false;
            double vdc = 0.0;
            int iOther = i == 1 ? 2 : 1;
            int[] statusVDC = { DCDCConv.GetVDCSwitchStatus(1), DCDCConv.GetVDCSwitchStatus(2) };
            if (statusVDC[i - 1] > 0)
            {
                // manipulate timer to ensure it does not switch off everything
                ushort tSwitchOff = DCDCConv.GetTimer();
                DCDCConv.SetTimer(0);
                DCDCConv.SwitchVDC(iOther, 0);
                DCDCConv.SwitchVDC(i, 1);
                MainBoard.SetMUX(GetVDCChannel(i));
                vdc = MainBoard.Adc!.GetVoltageDiff(ADS1115.CONFIG_MUX_DIFF_0_1, ADS1115.GAIN_TWOTHIRDS_6_144);
                MainBoard.SetMUX(-1);
                DCDCConv.SetTimer(tSwitchOff);
                DCDCConv.SwitchVDC(1, statusVDC[0]);
                DCDCConv.SwitchVDC(2, statusVDC[1]);
                status = true;
            }
            return (status, vdc);
        }

        public (bool status, double vdc) MeasureVDCmean(int i, int n)
        {
            using var analogMux = new AnalogMux(MainBoard);
            bool status = false;
            double vdc = 0.0;
            int iOther = i == 1 ? 2 : 1;
            int[] statusVDC = { DCDCConv.GetVDCSwitchStatus(1), DCDCConv.GetVDCSwitchStatus(2) };
            if (statusVDC[i - 1] > 0)
            {
                ushort tSwitchOff = DCDCConv.GetTimer();
                DCDCConv.SetTimer(0);
                DCDCConv.SwitchVDC(iOther, 0);
                DCDCConv.SwitchVDC(i, 1);
                var vMeas = new double[n];
                for (int j = 0; j < n; j++)
                {
                    MainBoard.SetMUX(GetVDCChannel(i));
                    vMeas[j] = MainBoard.Adc!.GetVoltageDiff(ADS1115.CONFIG_MUX_DIFF_0_1, ADS1115.GAIN_TWOTHIRDS_6_144);
                }
                MainBoard.SetMUX(-1);
                DCDCConv.SetTimer(tSwitchOff);
                DCDCConv.SwitchVDC(1, statusVDC[0]);
                DCDCConv.SwitchVDC(2, statusVDC[1]);
                vdc = TrimmedMean(vMeas);
                status = true;
            }
            return (status, vdc);
        }

        public (double r, double vdc, double vr) MeasR(int channel, int n)
        {
            using var analogMux = new AnalogMux(MainBoard);
            double vdc = 0;
            double vr = 0;
            double r = double.PositiveInfinity;
            bool measurementOK = true;
            if (n < 1)
            {
                n = 1;
            }
            try
            {
                int vdcChannel = channel < 60 ? GetVDCChannel(1) : GetVDCChannel(2);
                var vMeas = new double[n];
                for (int j = 0; j < n; j++)
                {
                    MainBoard.SetMUX(vdcChannel);
                    vMeas[j] = MainBoard.Adc!.GetVoltageDiff(ADS1115.CONFIG_MUX_DIFF_0_1, ADS1115.GAIN_TWOTHIRDS_6_144);
                }
                vdc = TrimmedMean(vMeas);
                if (measurementOK)
                {
                    vMeas = new double[n];
                    for (int j = 0; j < n; j++)
                    {
                        MainBoard.SetMUX(channel);
                        vMeas[j] = MainBoard.Adc!.GetVoltageDiff(ADS1115.CONFIG_MUX_DIFF_0_1, ADS1115.GAIN_TWOTHIRDS_6_144);
                    }
                    vr = TrimmedMean(vMeas);
                    if (vr < 0.01)
                    {
                        r = double.PositiveInfinity;
                    }
                    else
                    {
                        r = 0.82 * (vdc / vr - 1.0);
                    }
                    if (r < 0.0)
                    {
                        r = double.PositiveInfinity;
                    }
                }
            }
            catch
            {
                vdc = 0;
                vr = 0;
                r = double.PositiveInfinity;
            }
            MainBoard.SetMUX(-1);
            return (r, vdc, vr);
        }

        // Converted from MATLAB trimmedMean(): calculates the mean value of a vector.
        // If the vector contains more than 3 elements, one occurrence each of the
        // minimum and maximum values is excluded from the mean calculation.
        private static double TrimmedMean(double[] vec)
        {
            var list = new List<double>(vec);
            if (list.Count > 3)
            {
                int minIdx = 0;
                for (int j = 1; j < list.Count; j++)
                {
                    if (list[j] < list[minIdx])
                    {
                        minIdx = j;
                    }
                }
                list.RemoveAt(minIdx);

                int maxIdx = 0;
                for (int j = 1; j < list.Count; j++)
                {
                    if (list[j] > list[maxIdx])
                    {
                        maxIdx = j;
                    }
                }
                list.RemoveAt(maxIdx);
            }
            return list.Average();
        }

        public (int ret, bool[] bShort) CheckShortCircuit(double[] vMax, double[] rExpected)
        {
            // Make sure the analog multiplexer is really switched off at the
            // end, even if an exception is thrown
            using var analogMux = new AnalogMux(MainBoard);

            int numberOfEmitters = GetMaxNofEmitters();

            int ret = 0;
            int mainBoardStatusLED = 0;
            var bShort = new bool[numberOfEmitters];
            double vMaxShortCircuit = MainBoard.GetVMaxShortCircuit();
            var vMaxArr = new[] { Math.Min(vMax[0], vMaxShortCircuit), Math.Min(vMax[1], vMaxShortCircuit) };
            // Blink
            DCDCConv.SwitchStatusLED_DCDC(2);
            // set voltage
            DCDCConv.SetSiC450_Voltage(1, vMaxArr[0]);
            DCDCConv.SetSiC450_Voltage(2, vMaxArr[1]);
            // switch VDC2 off to make sure it does not influence the
            // measurement of the upper half
            DCDCConv.SwitchVDC(2, 0);
            // switch VDC1 on
            DCDCConv.SwitchVDC(1, 1);
            // measure VDC1
            MainBoard.SetMUX(GetVDCChannel(1));
            double vdc = MainBoard.Adc!.GetVoltageDiff(ADS1115.CONFIG_MUX_DIFF_0_1, ADS1115.GAIN_TWOTHIRDS_6_144);
            double threshold = MainBoard.RShunt * (vdc / (MainBoard.RShunt + 0.5 * rExpected[0]));
            for (int i = 1; i <= numberOfEmitters; i++)
            {
                // switch RGB LED to red
                MainBoard.SwitchRGBLED(i, 255, 0, 0, true, true);
                // toggle Main Board status LED
                mainBoardStatusLED = mainBoardStatusLED == 0 ? 1 : 0;
                MainBoard.SwitchStatusLED(mainBoardStatusLED);
                if (i == 61)
                {
                    // lower half
                    DCDCConv.SwitchVDC(1, 0);
                    // switch VDC2 on
                    DCDCConv.SwitchVDC(2, 1);
                    MainBoard.SetMUX(GetVDCChannel(2));
                    vdc = MainBoard.Adc!.GetVoltageDiff(ADS1115.CONFIG_MUX_DIFF_0_1, ADS1115.GAIN_TWOTHIRDS_6_144);
                    // resistances with less than 0.5*Rexpected are counted as short circuits
                    // max voltage caused by R = 0.5*Rexpected
                    threshold = MainBoard.RShunt * (vdc / (MainBoard.RShunt + 0.5 * rExpected[1]));
                }
                MainBoard.SetMUX(i - 1);
                var vr = new double[2];
                vr[0] = MainBoard.Adc!.GetVoltageDiff(ADS1115.CONFIG_MUX_DIFF_0_1, ADS1115.GAIN_TWOTHIRDS_6_144);
                vr[1] = MainBoard.Adc!.GetVoltageDiff(ADS1115.CONFIG_MUX_DIFF_0_1, ADS1115.GAIN_TWOTHIRDS_6_144);
                // measure maximum 5 times or as long as 2 measurements do not differ more than 20 %
                for (int k = 1; k <= 5; k++)
                {
                    double diff = Math.Abs(vr[0] - vr[1]);
                    if (diff < Math.Abs(0.2 * Math.Max(vr[0], vr[1])))
                    {
                        break;
                    }
                    vr[0] = vr[1];
                    vr[1] = MainBoard.Adc!.GetVoltageDiff(ADS1115.CONFIG_MUX_DIFF_0_1, ADS1115.GAIN_TWOTHIRDS_6_144);
                }
                if (vr[0] > threshold && vr[0] < vdc)
                {
                    bShort[i - 1] = true;
                    ret++;
                }
            }
            MainBoard.SetMUX(-1);
            // switch off RGB LEDs
            MainBoard.SwitchRGBLED(0, 0, 0, 0, true, true);
            // switch off Main Board status LED
            MainBoard.SwitchStatusLED(0);
            // switch off DCD status LED
            DCDCConv.SwitchStatusLED_DCDC(0);
            return (ret, bShort);
        }

        public (double[] vdc, double[] vr, double[] r, double[,] rm) CompleteMeasurement(
            int[] nSkip, int nMean, int numberOfEmitters,
            IProgress<(int current, int total)>? progress = null, CancellationToken cancellationToken = default)
        {
            // works with n= 0, 1, 2, 3, 4 (5, 6, 8, 10, 12)
            int mainBoardStatusLED = 0;
            if (nSkip[0] == 0)
            {
                nSkip[0] = 1;
            }
            if (nSkip[1] == 0)
            {
                nSkip[1] = 1;
            }
            // limit numberOfEmitters to maximum possible
            int n = MainBoard.MainBoardKindValue > MainBoardKind.FullBoardWithATtiny
                ? Math.Min(60 / nSkip[0], numberOfEmitters)
                : Math.Min((int)(60.0 / nSkip[0] + 60.0 / nSkip[1]), numberOfEmitters);

            var vdc = new double[n];
            var vr = new double[n];
            var r = new double[n];
            for (int idx = 0; idx < n; idx++)
            {
                r[idx] = double.PositiveInfinity;
            }
            var rm = new double[12, 10];
            for (int row = 0; row < 12; row++)
            {
                for (int col = 0; col < 10; col++)
                {
                    rm[row, col] = double.PositiveInfinity;
                }
            }
            bool debug = MainBoard.Debug;
            MainBoard.Debug = false;

            // remember if VDC1 and 2 are switched on
            int statusVDC1 = DCDCConv.GetVDCSwitchStatus(1);
            int statusVDC2 = DCDCConv.GetVDCSwitchStatus(2);
            // extend switchOffTimer of ATtiny if we are close to switchOff time
            ushort tSwitchOff = DCDCConv.GetTimer();
            if (tSwitchOff > 0 && tSwitchOff < 10)
            {
                // 10 min should be sufficient
                DCDCConv.SetTimer(10);
            }
            // switch VDC2 off to make sure it does not influence the
            // measurement of the upper half
            DCDCConv.SwitchVDC(2, 0);
            // switch VDC1 on
            DCDCConv.SwitchVDC(1, 1);
            int iStart = nSkip[0] > 1 ? 2 : 1;
            int k = 1; // position in vectors (1-based)
            int col1 = 1; // column in R-vector (1-based)
            int row1 = iStart; // row in R-vector (1-based)
            int i = iStart;
            bool lowerHalf = false;
            int nCurSkip = nSkip[0];
            for (int m = 1; m <= n; m++)
            {
                // switch RGB LED to orange
                MainBoard.SwitchRGBLED(i, 255, 204, 0, true, true);
                // toggle Main Board status LED
                mainBoardStatusLED = mainBoardStatusLED == 0 ? 1 : 0;
                MainBoard.SwitchStatusLED(mainBoardStatusLED);
                if (cancellationToken.IsCancellationRequested)
                {
                    break;
                }
                (double rVal, double vdcVal, double vrVal) = MeasR(i - 1, nMean);
                r[k - 1] = rVal;
                vdc[k - 1] = vdcVal;
                vr[k - 1] = vrVal;
                rm[row1 - 1, col1 - 1] = r[k - 1];
                progress?.Report((k, n));

                row1 += nCurSkip;
                if (i < 60)
                {
                    if (row1 > 6)
                    {
                        row1 = iStart;
                        col1++;
                        if (col1 > 10)
                        {
                            col1++;
                        }
                    }
                }
                else
                {
                    if (!lowerHalf)
                    {
                        nCurSkip = nSkip[1];
                        iStart = nCurSkip > 1 ? 2 : 1;
                        DCDCConv.SwitchVDC(1, 0);
                        DCDCConv.SwitchVDC(2, 1);
                        lowerHalf = true;
                        col1 = 1;
                        // looks strange, but is correct, for example with nSkip = 3, we start at row 9
                        row1 = 6 + i - 60 + iStart;
                    }
                    if (row1 > 12)
                    {
                        row1 = 6 + iStart;
                        col1++;
                        if (col1 > 10)
                        {
                            col1++;
                        }
                    }
                }
                k++;
                i += nCurSkip;
            }
            // set VDC's back
            DCDCConv.SwitchVDC(1, statusVDC1);
            DCDCConv.SwitchVDC(2, statusVDC2);
            MainBoard.SetMUX(-1);
            MainBoard.Debug = debug;

            // switch off RGB LEDs
            MainBoard.SwitchRGBLED(0, 0, 0, 0, true, true);
            // switch off Main Board status LED
            MainBoard.SwitchStatusLED(0);
            // switch off DCD status LED
            DCDCConv.SwitchStatusLED_DCDC(0);

            return (vdc, vr, r, rm);
        }

        public (bool ret, string strFilename) SaveMeasurement(
            string folder, string dDate, string dTime, string postfix, string[] snr,
            double[] vdc, double[] vr, double[] r)
        {
            var t = new double[3];
            for (int i = 0; i < 3; i++)
            {
                t[i] = MainBoard.TempSensor[i]?.GetTemperatureCelsius() ?? -273.5;
            }
            var strT = new System.Collections.Generic.List<string>();
            var strTHead = new System.Collections.Generic.List<string>();
            for (int i = 0; i < t.Length; i++)
            {
                if (t[i] > -273)
                {
                    strT.Add(t[i].ToString("F3"));
                    strTHead.Add($"T{strT.Count}");
                }
            }
            bool ret = true;
            string strFilename;
            // build filename
            if (!string.IsNullOrEmpty(postfix))
            {
                string strTime = dTime.Replace(':', '_');
                strFilename = Path.Combine(folder, $"{dDate}-{strTime}_{postfix}.csv");
            }
            else
            {
                strFilename = folder;
            }
            // generate folder if not existing
            string? targetFolder = Path.GetDirectoryName(strFilename);
            if (!string.IsNullOrEmpty(targetFolder) && !Directory.Exists(targetFolder))
            {
                try
                {
                    Directory.CreateDirectory(targetFolder);
                }
                catch
                {
                    LastErrorMessage = $"Folder: {targetFolder} could not be created!";
                }
            }
            // store header and data
            var header = new System.Collections.Generic.List<string> { "Date", "Time", "Channel", "SNr", "VDC", "VR", "R" };
            header.AddRange(strTHead);
            try
            {
                using var writer = new StreamWriter(strFilename, false, Encoding.UTF8);
                writer.WriteLine(string.Join('\t', header));
                for (int i = 0; i < vdc.Length; i++)
                {
                    string strSNr = snr.Length <= i ? snr[0] : snr[i];
                    var row = new System.Collections.Generic.List<string>
                    {
                        dDate, dTime, (i + 1).ToString(), strSNr,
                        vdc[i].ToString("F6"), vr[i].ToString("F6"), r[i].ToString("F6")
                    };
                    row.AddRange(strT);
                    writer.WriteLine(string.Join('\t', row));
                }
            }
            catch
            {
                LastErrorMessage = $"{LastErrorMessage} Cannot write measured data to {strFilename}. Please check access rights to the folder and free space on your disc!";
                ret = false;
            }
            return (ret, strFilename);
        }

        public void SwitchOff(bool complete = true)
        {
            MainBoard.SwitchOff(complete);
            DCDCConv.SwitchOff();
        }

        public bool SwitchOn(double vdc1, double vdc2, double f1, double f2, byte dutyCycle1, byte dutyCycle2, ushort duration)
        {
            bool ret = true;
            try
            {
                MainBoard.SwitchOn();
                DCDCConv.SwitchOn(vdc1, vdc2, f1, f2, dutyCycle1, dutyCycle2, duration);
            }
            catch
            {
                ret = false;
            }
            return ret;
        }

        public MainBoardKind GetMainBoardKind()
        {
            return MainBoard.MainBoardKindValue;
        }

        public int GetNofBanks()
        {
            return MainBoard.MainBoardKindValue > MainBoardKind.FullBoardWithATtiny ? 1 : 2;
        }

        public int GetMaxNofEmitters()
        {
            return MainBoard.MainBoardKindValue > MainBoardKind.FullBoardWithATtiny ? 60 : 120;
        }

        public int GetVDCChannel(int index)
        {
            if (MainBoard.MainBoardKindValue > MainBoardKind.FullBoardWithATtiny)
            {
                return index == 1 ? 60 : 0;
            }
            return index == 1 ? 120 : 124;
        }
    }
}
