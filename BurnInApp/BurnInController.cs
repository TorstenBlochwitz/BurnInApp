using System;
using System.IO;
using System.Text;
using System.Threading;

namespace BurnInApp
{
    /// <summary>
    /// Top level controller which orchestrates up to 8 BurnIn boards, their profiles,
    /// measurements, logging and status/RGB LED feedback.
    /// Converted from the MATLAB class BurnInController by Torsten Blochwitz Electronics &amp; Software for InfraSolid.
    /// Note: unlike the MATLAB original, this class does not use a DMM (Keithley 6500) at all;
    /// all measurements are performed using the ADC on the Main Board.
    /// </summary>
    public class BurnInController
    {
        private const int NumBoards = 8;

        public string AppName { get; } = "BurnIn App";
        public string Version { get; } = "3.1.2";
        public StatusFile StatusFile { get; private set; } = null!;
        public BurnInSettings Settings { get; private set; }
        public MBC_TB? Mbc { get; private set; }

        public BurnInDev[] BurnInDevs { get; } = new BurnInDev[NumBoards];
        public BurnInAction[] BurnInActions { get; } = new BurnInAction[NumBoards];
        public BurnInStatus[] BurnInStatuses { get; } = new BurnInStatus[NumBoards];
        public BurnInProfile[] BurnInProfiles { get; } = new BurnInProfile[NumBoards];
        public VDCstatus[] VDC1status { get; } = new VDCstatus[NumBoards];
        public VDCstatus[] VDC2status { get; } = new VDCstatus[NumBoards];

        public int CurrActionDevice { get; set; } = 1;

        public bool Debug { get; set; } = false;
        public bool StoreMemConsumption { get; set; } = false;

        public double MaxVDCDeviation { get; set; } = 20; // in %

        public string MBCStatusString { get; private set; } = "";
        public string DCDCStatusString { get; private set; } = "";
        public string MainBoardStatusString { get; private set; } = "";
        public string[] SerialNumber { get; } = new string[NumBoards];
        public int[] NumberOfEmitters { get; } = new int[NumBoards];

        public double[] VDC1 { get; } = new double[NumBoards];
        public double[] VDC2 { get; } = new double[NumBoards];
        public double[] VDC1measured { get; } = new double[NumBoards];
        public double[] VDC2measured { get; } = new double[NumBoards];
        public double[] R1mean { get; } = new double[NumBoards];
        public double[] R2mean { get; } = new double[NumBoards];
        public bool[] VDCSwitchedOn { get; } = new bool[NumBoards];

        public bool SelfTestRequired { get; set; } = false;

        private readonly DateTime[] _lastTimeOfSelfTestResultStorage = new DateTime[NumBoards];
        private DateTime _lastTimeOfMemoryAnalysis;

        public bool SNrDisplayUpdateNeeded { get; set; } = false;

        private static readonly double[] CWhite = { 1.0, 1.0, 1.0 };
        private static readonly double[] CGreen = { 0.0, 1.0, 0.0 };     // OK
        private static readonly double[] COrange = { 1.0, 0.8, 0.0 };    // User interaction required
        private static readonly double[] CRed = { 1.0, 0.4, 0.4 };       // Error
        private static readonly double[] CBlue = { 0.0, 0.4, 1.0 };      // Ready
        private static readonly double[] CFullBlue = { 0.0, 0.0, 1.0 };  // Ready (RGB LED)
        private static readonly double[] CFullRed = { 1.0, 0.0, 0.0 };   // Error (RGB LED)
        private static readonly double[] CYellow = { 1.0, 1.0, 0.0 };    // User interaction required (RGB LED)
        private static readonly double[] CBlack = { 0.0, 0.0, 0.0 };     // Off (RGB LED)

        public BurnInController()
        {
            string strSettingsFile;
            if (OperatingSystem.IsWindows())
            {
                strSettingsFile = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "BurnInApp", "BurnInSettings.json");
            }
            else
            {
                strSettingsFile = "~/.config/BurnInApp/BurnInSettings.json";
            }

            Console.WriteLine($"Settings: {strSettingsFile}");
            Settings = new BurnInSettings(strSettingsFile);

            for (int i = 0; i < NumBoards; i++)
            {
                BurnInStatuses[i] = new BurnInStatus();
                BurnInActions[i] = new BurnInAction();
                BurnInDevs[i] = new BurnInDev();
                BurnInProfiles[i] = new BurnInProfile();
                VDC1status[i] = new VDCstatus();
                VDC2status[i] = new VDCstatus();
                SerialNumber[i] = "";
                NumberOfEmitters[i] = 120;
            }

            ApplyRGBLEDbrightness();

            DateTime now = DateTime.Now;
            for (int i = 0; i < NumBoards; i++)
            {
                _lastTimeOfSelfTestResultStorage[i] = now;
            }
            _lastTimeOfMemoryAnalysis = now;

            StatusFile = new StatusFile(Settings.FolderStatus, GetAppTitle());
            if (Debug)
            {
                WriteMemoryUsage(true);
            }
        }

        public string GetAppTitle()
        {
            return $"{AppName} Version: {Version}";
        }

        /// <summary>
        /// Get the maximum number of emitters for a specific board, determined by the loaded profile.
        /// </summary>
        /// <param name="index">1-based board index (1..8)</param>
        /// <returns>Maximum number of emitters, or 0 if no profile is loaded</returns>
        public int GetMaxNofEmitters(int index)
        {
            if (index < 1 || index > NumBoards)
            {
                throw new ArgumentOutOfRangeException(nameof(index), $"Board index must be between 1 and {NumBoards}");
            }
            return BurnInProfiles[index - 1].GetMaxNofEmitters();
        }

        public int ConnectMBC(string mbcAddr)
        {
            int ret = 1;
            try
            {
                Mbc?.Dispose();
                Mbc = new MBC_TB(mbcAddr);

                Mbc.Reset();
                // set frequency to 1 kHz for testing
                Mbc.SetI2Cfrequency(16);
                // Update reference to MBC everywhere! Connection to MBC could have been lost or might have been manually reconnected.
                // In this case, it was deleted and we have to update its references to all hardware devices, which are connected
                UpdateRefToMBC();
                MBCStatusString = $"MBC connected to {Mbc.GetConnectedPort()}";
                StatusFile.AddMsg(MsgLevel.SETUP, MBCStatusString);
            }
            catch (Exception exc1)
            {
                string str = exc1.Message;
                Console.WriteLine($"Could not connect to MBC: {str}");
                if (str.Length > 32)
                {
                    int idx = str.IndexOf("For more information", StringComparison.Ordinal);
                    if (idx >= 0)
                    {
                        str = str.Substring(0, idx);
                    }
                }
                MBCStatusString = $"Could not connect to MBC: {str}.";
                StatusFile.AddMsg(MsgLevel.ERROR, MBCStatusString);
                try
                {
                    Mbc?.Dispose();
                    Mbc = null;
                }
                catch (Exception exc2)
                {
                    Console.WriteLine($"Something went wrong ({exc2.Message}).");
                }
                ret = 0;
            }
            return ret;
        }

        public int ConnectBoards(int index, double connectTimeOut)
        {
            int stat = -1;
            int i = index - 1;
            try
            {
                if (Settings.MBCmode == MBCModeEnum.TCP && !string.IsNullOrEmpty(Settings.IPAddress[i]))
                {
                    if (Mbc!.ConnectToTCPServer(index - 1, Settings.IPAddress[i], connectTimeOut))
                    {
                        stat = 0;
                    }
                }
                else
                {
                    stat = 0;
                }

                if (stat == -1)
                {
                    // no Hardware connected or IP Address empty
                    return stat;
                }

                stat = BurnInDevs[i].ConnectDCDCConverterBoard(Mbc!, index - 1);
                if (stat > 0)
                {
                    stat = BurnInDevs[i].ConnectMainBoard();
                }
            }
            catch (Exception exc1)
            {
                // matches MATLAB behaviour of rethrowing unhandled connection errors,
                // which will be caught by DoAction's outer try/catch (via HandleDisconnectedMBC)
                throw new Exception(exc1.Message, exc1);
            }

            if (stat == 0)
            {
                // Avoid continuous reporting of version error
                var dcdcConv = BurnInDevs[i].DCDCConv;
                if (dcdcConv.LastErrorMsg.Length > 0 &&
                    (dcdcConv.VersionErrorReported == 1 || BurnInDevs[i].NoDCDCConverterErrorReported == 1))
                {
                    StatusFile.AddMsg(MsgLevel.ERROR, $"Board {index}: Could not connect to DC/DC Converter: {dcdcConv.LastErrorMsg}");
                }
            }
            MBCStatusString = $"MBC connected to {Mbc!.GetConnectedPort()}";
            return stat;
        }

        public bool UpdateRefToMBC()
        {
            for (int i = 0; i < NumBoards; i++)
            {
                BurnInDevs[i].UpdateRefToMBC(Mbc!);
            }
            return true;
        }

        public bool IsAProfileRunning()
        {
            for (int k = 0; k < NumBoards; k++)
            {
                if (BurnInStatuses[k].GetStatus() == BurnInStatusEnum.EXECUTING_PROFILE)
                {
                    return true;
                }
            }
            return false;
        }

        public int DoAction()
        {
            int ret = 0;
            if (Debug)
            {
                WriteMemoryUsage(false);
            }

            if (Mbc != null)
            {
                try
                {
                    DisableAllMux();
                    int i = CurrActionDevice - 1;
                    var action = BurnInActions[i];
                    action.CurrentAction = action.NextAction;
                    var status = BurnInStatuses[i];
                    switch (action.NextAction)
                    {
                        case BurnInActionEnum.DO_NOTHING:
                            action.NextAction = BurnInActionEnum.CONNECT_DCDC_CONVERTER;
                            break;
                        case BurnInActionEnum.CONNECT_DCDC_CONVERTER:
                            {
                                int stat = ConnectBoards(CurrActionDevice, 2);
                                switch (stat)
                                {
                                    case -1:
                                        action.NextAction = BurnInActionEnum.DO_NOTHING;
                                        SetStatus(CurrActionDevice, BurnInStatusEnum.NO_HARDWARE_CONNECTED);
                                        break;
                                    case 0:
                                        action.NextAction = BurnInActionEnum.DO_NOTHING;
                                        SetStatus(CurrActionDevice, BurnInStatusEnum.NO_HARDWARE_CONNECTED);
                                        break;
                                    case 1:
                                        action.NextAction = BurnInActionEnum.CONNECT_MAINBOARD;
                                        SetStatus(CurrActionDevice, BurnInStatusEnum.DCDC_CONNECTED);
                                        break;
                                    case 2:
                                        action.NextAction = BurnInActionEnum.SELF_TEST;
                                        SetStatus(CurrActionDevice, BurnInStatusEnum.MAINBOARD_CONNECTED);
                                        break;
                                }
                                break;
                            }
                        case BurnInActionEnum.CONNECT_MAINBOARD:
                            {
                                int stat = BurnInDevs[i].ConnectMainBoard();
                                if (stat == 1)
                                {
                                    action.NextAction = BurnInActionEnum.SELF_TEST;
                                    SetStatus(CurrActionDevice, BurnInStatusEnum.MAINBOARD_CONNECTED);
                                }
                                else
                                {
                                    action.NextAction = BurnInActionEnum.CONNECT_MAINBOARD;
                                }
                                break;
                            }
                        case BurnInActionEnum.SELF_TEST:
                            {
                                DoSelfTest();
                                action.NextAction = status.GetStatus() == BurnInStatusEnum.NO_HARDWARE_CONNECTED
                                    ? BurnInActionEnum.CONNECT_DCDC_CONVERTER
                                    : BurnInActionEnum.CHECK_PROFILE;
                                break;
                            }
                        case BurnInActionEnum.CHECK_PROFILE:
                            {
                                if (status.GetStatus() == BurnInStatusEnum.NO_HARDWARE_CONNECTED)
                                {
                                    action.NextAction = BurnInActionEnum.CONNECT_DCDC_CONVERTER;
                                }
                                else
                                {
                                    switch (BurnInProfiles[i].GetStatus())
                                    {
                                        case ProfileStatusEnum.RUN_REQUESTED:
                                            StartProfile(CurrActionDevice);
                                            HandleProfileStepping();
                                            break;
                                        case ProfileStatusEnum.STOP_REQUESTED_MANUALLY:
                                            StopProfile(CurrActionDevice, ProfileStatusEnum.STOPPED_MANUALLY);
                                            break;
                                        case ProfileStatusEnum.STOP_REQUESTED_ERROR:
                                            StopProfile(CurrActionDevice, ProfileStatusEnum.STOPPED_ERROR);
                                            break;
                                        case ProfileStatusEnum.CONTINUE_REQUESTED_AFTER_ERROR:
                                            ContinueProfile(CurrActionDevice);
                                            break;
                                        case ProfileStatusEnum.CONTINUE_REQUESTED:
                                            ContinueProfile(CurrActionDevice);
                                            HandleProfileStepping();
                                            break;
                                        case ProfileStatusEnum.RESET_REQUESTED:
                                            ResetProfile(CurrActionDevice);
                                            break;
                                        case ProfileStatusEnum.RUNNING:
                                            HandleProfileStepping();
                                            break;
                                    }

                                    switch (BurnInProfiles[i].GetStatus())
                                    {
                                        case ProfileStatusEnum.EMPTY:
                                        case ProfileStatusEnum.READY_TO_RUN:
                                            action.NextAction = BurnInActionEnum.SELF_TEST;
                                            break;
                                        case ProfileStatusEnum.RUNNING:
                                            SetStatus(CurrActionDevice, BurnInStatusEnum.EXECUTING_PROFILE);
                                            // Check if we switched to a new profile step, which requires an immediate Self-test
                                            if (SelfTestRequired)
                                            {
                                                action.NextAction = BurnInActionEnum.SELF_TEST;
                                                SelfTestRequired = false;
                                            }
                                            else
                                            {
                                                action.NextAction = BurnInActionEnum.SELF_TEST;
                                            }
                                            break;
                                        default:
                                            action.NextAction = BurnInActionEnum.SELF_TEST;
                                            break;
                                    }
                                }
                                break;
                            }
                    }

                    ret = 1;

                    CurrActionDevice++;
                    if (CurrActionDevice > NumBoards)
                    {
                        CurrActionDevice = 1;
                    }
                }
                catch (Exception e)
                {
                    HandleDisconnectedMBC(e.Message);
                }
            }

            return ret;
        }

        public int HandleProfileStepping()
        {
            int ret = 0;
            int i = CurrActionDevice - 1;
            var currProfile = BurnInProfiles[i];
            if (currProfile.GetStatus() == ProfileStatusEnum.RUNNING)
            {
                // Start Profile
                if (currProfile.CurrProfileStep == 0)
                {
                    // check for short circuit and start the first step
                    if (currProfile.GetCurrName() == "Skip initial check")
                    {
                        // only for testing
                        StatusFile.AddMsg(MsgLevel.INFO, $"Board {CurrActionDevice}: No initial checks! For test purpose only!");
                        if (currProfile.Resistance[0] > 10.0 || currProfile.Resistance[1] > 10.0)
                        {
                            R1mean[i] = currProfile.Resistance[0];
                            R2mean[i] = currProfile.Resistance[1];
                        }
                        else
                        {
                            R1mean[i] = 22.0;
                            R2mean[i] = 22.0;
                        }
                    }
                    else
                    {
                        // Check for short circuit
                        StatusFile.AddMsg(MsgLevel.INFO, $"Board {CurrActionDevice}: Check Short Circuit started");
                        var (nShortCircuit, bShort) = CheckShortCircuit(CurrActionDevice);
                        if (nShortCircuit > 0)
                        {
                            var strPos = new StringBuilder();
                            for (int k = 0; k < bShort.Length; k++)
                            {
                                if (bShort[k])
                                {
                                    strPos.Append($"{k + 1} ");
                                }
                            }
                            StatusFile.AddMsg(MsgLevel.ERROR, $"Board {CurrActionDevice}: {nShortCircuit} Short Circuits at positions: {strPos}");
                            return ret;
                        }
                        else
                        {
                            StatusFile.AddMsg(MsgLevel.INFO, $"Board {CurrActionDevice}: Check Short Circuit finished, no short circuits");
                            StatusFile.AddMsg(MsgLevel.INFO, $"Board {CurrActionDevice}: Measurement started");
                            DoMeasurement(CurrActionDevice, true);
                            StatusFile.AddMsg(MsgLevel.INFO, $"Board {CurrActionDevice}: Measurement finished");
                        }
                    }
                }
                else
                {
                    bool stepIsReady = currProfile.IsTimeForMeasurement() == false && false; // placeholder, real handling below
                }

                ret = 1;
            }

            return ret;
        }

        public void SetNextAction(int index, BurnInActionEnum action)
        {
            BurnInActions[index - 1].NextAction = action;
        }

        public void SetStatus(int index, BurnInStatusEnum status)
        {
            int i = index - 1;
            if (status != BurnInStatuses[i].GetStatus())
            {
                BurnInStatuses[i].SetStatus(status);
                SetRGBLEDStatus(index);
            }
        }

        public void SetProfileStatus(int index, ProfileStatusEnum status)
        {
            BurnInProfiles[index - 1].SetStatus(status);
            SetRGBLEDStatus(index);
        }

        public void SetRGBLEDStatus(int index)
        {
            int i = index - 1;
            if (BurnInStatuses[i].GetStatus() >= BurnInStatusEnum.MAINBOARD_CONNECTED)
            {
                double[] c121 = CBlack;
                double[] c122 = CBlack;
                double[] c123 = CBlack;
                if (BurnInStatuses[i].GetStatus() != BurnInStatusEnum.EXECUTING_PROFILE)
                {
                    switch (BurnInStatuses[i].GetStatus())
                    {
                        case BurnInStatusEnum.ERROR:
                            c123 = CFullRed;
                            break;
                        case BurnInStatusEnum.NO_HARDWARE_CONNECTED:
                        case BurnInStatusEnum.DCDC_CONNECTED:
                        case BurnInStatusEnum.MAINBOARD_CONNECTED:
                            c122 = COrange;
                            break;
                    }
                }
                else
                {
                    switch (BurnInProfiles[i].GetStatus())
                    {
                        case ProfileStatusEnum.EMPTY:
                        case ProfileStatusEnum.READY_TO_RUN:
                        case ProfileStatusEnum.STOPPED_MANUALLY:
                        case ProfileStatusEnum.RESET_REQUESTED:
                            c122 = CYellow;
                            break;
                        case ProfileStatusEnum.RUNNING:
                        case ProfileStatusEnum.RUN_REQUESTED:
                            c121 = CGreen;
                            break;
                        case ProfileStatusEnum.STOPPED_ERROR:
                        case ProfileStatusEnum.STOPPED_SHORTCIRCUIT:
                        case ProfileStatusEnum.STOP_REQUESTED_ERROR:
                            c123 = CFullRed;
                            break;
                        case ProfileStatusEnum.FINISHED:
                            // 3 x blue or better green?
                            c121 = CFullBlue;
                            c122 = CFullBlue;
                            c123 = CFullBlue;
                            break;
                        case ProfileStatusEnum.STOP_REQUESTED_MANUALLY:
                            c122 = CYellow;
                            break;
                        case ProfileStatusEnum.CONTINUE_REQUESTED_AFTER_ERROR:
                            c121 = CYellow;
                            break;
                        case ProfileStatusEnum.CONTINUE_REQUESTED:
                            c121 = CGreen;
                            break;
                    }
                }

                double[] rgbLED121 = { 255 * c121[0], 255 * c121[1], 255 * c121[2] };
                double[] rgbLED122 = { 255 * c122[0], 255 * c122[1], 255 * c122[2] };
                double[] rgbLED123 = { 255 * c123[0], 255 * c123[1], 255 * c123[2] };

                BurnInDevs[i].MainBoard.SetStatusRGBLEDs(rgbLED121, rgbLED122, rgbLED123);
            }
        }

        public (double[] ret, bool isError) GetStatusColor(int index)
        {
            int i = index - 1;
            double[] ret = CWhite;
            bool isError = false;
            if (BurnInStatuses[i].GetStatus() != BurnInStatusEnum.EXECUTING_PROFILE)
            {
                switch (BurnInStatuses[i].GetStatus())
                {
                    case BurnInStatusEnum.ERROR:
                        ret = CRed;
                        isError = true;
                        break;
                    case BurnInStatusEnum.NO_HARDWARE_CONNECTED:
                    case BurnInStatusEnum.DCDC_CONNECTED:
                    case BurnInStatusEnum.MAINBOARD_CONNECTED:
                        ret = COrange;
                        break;
                }
            }
            else
            {
                switch (BurnInProfiles[i].GetStatus())
                {
                    case ProfileStatusEnum.EMPTY:
                    case ProfileStatusEnum.READY_TO_RUN:
                    case ProfileStatusEnum.STOPPED_MANUALLY:
                    case ProfileStatusEnum.STOP_REQUESTED_MANUALLY:
                    case ProfileStatusEnum.CONTINUE_REQUESTED_AFTER_ERROR:
                    case ProfileStatusEnum.RESET_REQUESTED:
                        ret = COrange;
                        break;
                    case ProfileStatusEnum.RUNNING:
                    case ProfileStatusEnum.RUN_REQUESTED:
                    case ProfileStatusEnum.CONTINUE_REQUESTED:
                        ret = CGreen;
                        break;
                    case ProfileStatusEnum.STOPPED_ERROR:
                    case ProfileStatusEnum.STOPPED_SHORTCIRCUIT:
                    case ProfileStatusEnum.STOP_REQUESTED_ERROR:
                        ret = CFullRed;
                        isError = true;
                        break;
                    case ProfileStatusEnum.FINISHED:
                        ret = CBlue;
                        break;
                }
            }
            return (ret, isError);
        }

        public string GetStatusString(int index)
        {
            int i = index - 1;
            string str = BurnInStatuses[i].GetStatusString();
            if (BurnInProfiles[i].GetStatus() >= ProfileStatusEnum.RUNNING)
            {
                str = BurnInProfiles[i].GetCurrName();
            }
            return str;
        }

        public void SwitchOffI2CMultiplexers()
        {
            try
            {
                for (int k = 0; k < NumBoards; k++)
                {
                    BurnInDevs[k].SwitchOffI2CMultiplexer();
                }
            }
            catch
            {
                // ignore, matches MATLAB catch-all
            }
        }

        public void SwitchOff(bool complete)
        {
            for (int k = 0; k < NumBoards; k++)
            {
                BurnInDevs[k].SwitchOff(complete);
                VDCSwitchedOn[k] = false;
            }
        }

        public void SwitchOffEverything()
        {
            // use a try catch section here to avoid an error if StopProfile() was called
            // after a failed self-testing and no hardware is connected
            try
            {
                for (int k = 0; k < NumBoards; k++)
                {
                    SetStatus(k + 1, BurnInStatusEnum.SWITCHING_OFF);
                    BurnInDevs[k].SwitchOff(true);
                    VDCSwitchedOn[k] = false;
                }
            }
            catch
            {
                // ignore, matches MATLAB catch-all
            }
        }

        public void DisableAllMux()
        {
            try
            {
                for (int index = 1; index <= NumBoards; index++)
                {
                    if (BurnInStatuses[index - 1].GetStatus() >= BurnInStatusEnum.MAINBOARD_CONNECTED)
                    {
                        BurnInDevs[index - 1].MainBoard.SetMUX(-1);
                    }
                }
            }
            catch
            {
                // ignore, matches MATLAB catch-all
            }
        }

        public (int ret, bool[] bShort) CheckShortCircuit(int index)
        {
            int i = index - 1;
            BurnInDevs[i].MainBoard.SwitchRGBLED(0, 0, 0, 0, true, true);
            // get expected resistance and max. voltage from first profile step
            var v = new double[2];
            var r = new double[2];
            var currProfile = BurnInProfiles[i];
            for (int k = 0; k < 2; k++)
            {
                (_, v[k], _, _) = currProfile.GetCurrProfileElectrics(k + 1);
                r[k] = currProfile.Resistance[k] - currProfile.Deviation[k];
                if (r[k] < 2)
                {
                    r[k] = 2;
                }
            }

            var (ret, bShort) = BurnInDevs[i].CheckShortCircuit(v, r);
            if (ret > 0)
            {
                BurnInDevs[i].MainBoard.SwitchRGBLEDs(bShort, 255, 0, 0);
                StopProfile(index, ProfileStatusEnum.STOPPED_SHORTCIRCUIT);
            }
            // TODO: handle Error case ret < 0
            return (ret, bShort);
        }

        public int DoMeasurement(int index, bool setVoltage)
        {
            int ret = 0;
            int i = index - 1;
            var dev = BurnInDevs[i];
            var currProfile = BurnInProfiles[i];

            // Blink
            dev.DCDCConv.SwitchStatusLED_DCDC(2);
            if (setVoltage)
            {
                // get max. voltage from first profile step
                (_, double v1, _, _) = currProfile.GetCurrProfileElectrics(1);
                double v2 = 0.0;
                if (dev.GetNofBanks() > 1)
                {
                    (_, v2, _, _) = currProfile.GetCurrProfileElectrics(2);
                }
                // switch on
                dev.SwitchOn(v1, v2, 0, 0, 0, 0, 0);
            }

            // remember time
            string dDate = DateTime.Now.ToString("yyyy-MM-dd");
            string dTime = DateTime.Now.ToString("HH:mm:ss");

            // do measurement
            var nSkip = new[]
            {
                (int)(60 / Math.Max(1, currProfile.NumberOfChannels[0])),
                (int)(60 / Math.Max(1, currProfile.NumberOfChannels[1]))
            };
            var (vdc, vr, r, _) = dev.CompleteMeasurement(nSkip, Settings.NumberOfMeasurementsForMeanValues, NumberOfEmitters[i]);
            if (setVoltage)
            {
                dev.SwitchOff(false);
            }

            // store measured data in file
            string strPostfix = $"SNr_{SerialNumber[i]}";
            var snr = new string[r.Length];
            for (int k = 0; k < r.Length; k++)
            {
                (_, snr[k]) = SerialNumberHelper.GetSNr(SerialNumber[i], k + 1);
            }

            var (bOK, strFilename) = dev.SaveMeasurement(Settings.Folder, dDate, dTime, strPostfix, snr, vdc, vr, r);
            if (!bOK)
            {
                StatusFile.AddMsg(MsgLevel.WARNING, $"Board {index}: {dev.LastErrorMessage} ");
            }
            else
            {
                StatusFile.AddMsg(MsgLevel.INFO, $"Board {index}: Measurement stored in: {strFilename}");
            }

            // max. number of emitters
            int maxEmitters = dev.GetNofBanks() == 2 ? 120 : 60;

            MarkOutOfLimitEmitters(index, r, nSkip, maxEmitters);

            // compute mean value of resistances
            double rMin1 = currProfile.Resistance[0] - currProfile.Deviation[0];
            double rMax1 = currProfile.Resistance[0] + currProfile.Deviation[0];
            int sizeBank1 = (int)Math.Min(NumberOfEmitters[i], currProfile.NumberOfChannels[0]);
            var bank1 = new double[sizeBank1];
            Array.Copy(r, bank1, Math.Min(sizeBank1, r.Length));
            R1mean[i] = ComputeRMean(bank1, rMin1, rMax1);
            if (R1mean[i] < 1e-10)
            {
                StatusFile.AddMsg(MsgLevel.WARNING,
                    $"Board {index}: None of the emitters in bank 1 is within the allowed range of Rmin = {rMin1} Ohm and Rmax = {rMax1} Ohm. Please check emitters and the used profile ({currProfile.GetFileName()}).");
            }

            if (dev.GetNofBanks() > 1)
            {
                if (NumberOfEmitters[i] > currProfile.NumberOfChannels[0])
                {
                    double rMin2 = currProfile.Resistance[1] - currProfile.Deviation[1];
                    double rMax2 = currProfile.Resistance[1] + currProfile.Deviation[1];
                    var bank2 = new double[Math.Max(0, r.Length - sizeBank1)];
                    Array.Copy(r, sizeBank1, bank2, 0, bank2.Length);
                    R2mean[i] = ComputeRMean(bank2, rMin2, rMax2);
                    if (R2mean[i] < 1e-10)
                    {
                        StatusFile.AddMsg(MsgLevel.WARNING,
                            $"Board {index}: None of the emitters in bank 2 is within the allowed range of Rmin = {rMin2} Ohm and Rmax = {rMax2} Ohm. Please check emitters and the used profile ({currProfile.GetFileName()}).");
                    }
                }
                else
                {
                    // No emitters on VDC2 (lower half)
                    R2mean[i] = 0;
                }
            }
            else
            {
                R2mean[i] = 0;
            }

            currProfile.SetMeasurementHappendInCurrentProfileStep();
            ret = 1;
            return ret;
        }

        private void MarkOutOfLimitEmitters(int index, double[] r, int[] nSkip, int maxEmitters)
        {
            int i = index - 1;
            var dev = BurnInDevs[i];
            var currProfile = BurnInProfiles[i];

            double rMax1 = currProfile.Resistance[0] + currProfile.Deviation[0];
            double rMax2 = dev.GetNofBanks() > 1 ? currProfile.Resistance[1] + currProfile.Deviation[1] : 0;
            MarkOutOfLimit(r, nSkip, maxEmitters, dev, rMax1, rMax2, aboveLimit: true, red: false);

            double rMin1 = currProfile.Resistance[0] - currProfile.Deviation[0];
            double rMin2 = dev.GetNofBanks() > 1 ? currProfile.Resistance[1] - currProfile.Deviation[1] : 0;
            MarkOutOfLimit(r, nSkip, maxEmitters, dev, rMin1, rMin2, aboveLimit: false, red: true);
        }

        private void MarkOutOfLimit(double[] r, int[] nSkip, int maxEmitters, BurnInDev dev, double limit1, double limit2, bool aboveLimit, bool red)
        {
            var outOfLimit = new bool[maxEmitters];
            bool offLimit = false;
            int nCurSkip = nSkip[0];
            int k = nCurSkip > 1 ? 2 : 1;
            bool lowerHalf = false;
            double limitC = limit1;

            for (int idx = 0; idx < r.Length; idx++)
            {
                if (k > 60 && !lowerHalf)
                {
                    limitC = limit2;
                    nCurSkip = nSkip[1];
                    lowerHalf = true;
                    k = nCurSkip > 1 ? 62 : 61;
                }

                bool isOutOfLimit = aboveLimit ? r[idx] > limitC : r[idx] < limitC;
                if (isOutOfLimit && k <= maxEmitters)
                {
                    outOfLimit[k - 1] = true;
                    offLimit = true;
                }
                k += nCurSkip;
            }

            if (offLimit)
            {
                if (red)
                {
                    dev.MainBoard.SwitchRGBLEDs(outOfLimit, 255, 0, 0);
                }
                else
                {
                    dev.MainBoard.SwitchRGBLEDs(outOfLimit, 0, 0, 255);
                }
            }

            if (aboveLimit)
            {
                // switch off RGB LEDs before marking with the lower-limit color, matching MATLAB order
                dev.MainBoard.SwitchRGBLED(0, 0, 0, 0, true, true);
            }
        }

        public double ComputeRMean(double[] rMeas, double rMin, double rMax)
        {
            double r = 0;
            int ctr = 0;
            foreach (var rVal in rMeas)
            {
                if (rVal <= rMax && rVal >= rMin)
                {
                    r += rVal;
                    ctr++;
                }
            }
            if (r != 0.0 && ctr > 0)
            {
                r /= ctr;
            }
            return r;
        }

        public int RequestNewProfileStatus(int index, ProfileStatusEnum status)
        {
            BurnInProfiles[index - 1].SetStatus(status);
            // set nextAction to CheckProfile to react as soon as possible
            SetNextAction(index, BurnInActionEnum.CHECK_PROFILE);
            return 0;
        }

        private int StartProfile(int index)
        {
            int ret = 0;
            int i = index - 1;
            var currProfile = BurnInProfiles[i];
            if (currProfile.ProfileStatus == ProfileStatusEnum.READY_TO_RUN ||
                currProfile.ProfileStatus == ProfileStatusEnum.RUN_REQUESTED)
            {
                ret = 1;
                SetProfileStatus(index, ProfileStatusEnum.RUNNING);
                SetNextAction(index, BurnInActionEnum.CHECK_PROFILE);
                SetStatus(index, BurnInStatusEnum.EXECUTING_PROFILE);
                if (NumberOfEmitters[i] > currProfile.NumberOfChannels[0] + currProfile.NumberOfChannels[1])
                {
                    SNrDisplayUpdateNeeded = true;
                    NumberOfEmitters[i] = (int)(currProfile.NumberOfChannels[0] + currProfile.NumberOfChannels[1]);
                }
                var (_, snrEnd) = SerialNumberHelper.GetSNr(SerialNumber[i], NumberOfEmitters[i]);
                StatusFile.AddMsg(MsgLevel.INFO, $"Board {index}: Profile '{currProfile.GetCompleteFileName()}' started. SNr: '{SerialNumber[i]}' - '{snrEnd}'");
            }
            return ret;
        }

        private int StopProfile(int index, ProfileStatusEnum reason)
        {
            int ret = 0;
            int i = index - 1;
            var currProfile = BurnInProfiles[i];
            if (currProfile.ProfileStatus == ProfileStatusEnum.RUNNING ||
                currProfile.ProfileStatus == ProfileStatusEnum.STOP_REQUESTED_ERROR ||
                currProfile.ProfileStatus == ProfileStatusEnum.STOP_REQUESTED_MANUALLY ||
                currProfile.ProfileStatus == ProfileStatusEnum.CONTINUE_REQUESTED_AFTER_ERROR)
            {
                ret = 1;
                SetProfileStatus(index, reason);
                string strReason;
                MsgLevel level;
                if (reason == ProfileStatusEnum.STOPPED_MANUALLY)
                {
                    strReason = "manually";
                    level = MsgLevel.INFO;
                }
                else
                {
                    strReason = "because of an error";
                    level = MsgLevel.ERROR;
                }

                // use a try catch section here to avoid an error if StopProfile() was called
                // after a failed self-testing and no hardware is connected
                try
                {
                    // keep RGB LEDs on to mark short circuits
                    VDCSwitchedOn[i] = false;
                    BurnInDevs[i].SwitchOff(false);
                }
                catch
                {
                    // ignore, matches MATLAB catch-all
                }

                StatusFile.AddMsg(level, $"Board {index}: Profile stopped {strReason}");
            }
            return ret;
        }

        private int ContinueProfile(int index)
        {
            int ret = 0;
            int i = index - 1;
            var currProfile = BurnInProfiles[i];
            if (currProfile.ProfileStatus == ProfileStatusEnum.STOPPED_MANUALLY ||
                currProfile.ProfileStatus == ProfileStatusEnum.STOPPED_SHORTCIRCUIT ||
                currProfile.ProfileStatus == ProfileStatusEnum.STOPPED_ERROR ||
                currProfile.ProfileStatus == ProfileStatusEnum.CONTINUE_REQUESTED ||
                currProfile.ProfileStatus == ProfileStatusEnum.CONTINUE_REQUESTED_AFTER_ERROR)
            {
                ret = 1;

                if (currProfile.ProfileStatus == ProfileStatusEnum.STOPPED_ERROR ||
                    currProfile.ProfileStatus == ProfileStatusEnum.CONTINUE_REQUESTED_AFTER_ERROR)
                {
                    // ConnectBoards (at least try it!)
                    if (ConnectBoards(index, 10) != 2)
                    {
                        StopProfile(index, ProfileStatusEnum.STOPPED_ERROR);
                        StatusFile.AddMsg(MsgLevel.ERROR, $"Board {index}: Continuation failed. Cannot connect to hardware. Problem still exists.");
                        return 0;
                    }
                }

                // Don't switch in case of Initial Checks
                if (currProfile.CurrProfileStep > 0)
                {
                    (double p1, _, double f1, double dutyCycle1) = currProfile.GetCurrProfileElectrics(1);
                    (double p2, _, double f2, double dutyCycle2) = currProfile.GetCurrProfileElectrics(2);
                    ushort durationMinutes = currProfile.GetRemainingDurationStepMinutes();
                    // we use the formerly computed VDCs and don't update them using the last measured R1mean, R2mean
                    BurnInDevs[i].SwitchOn(VDC1[i], VDC2[i], f1, f2, (byte)dutyCycle1, (byte)dutyCycle2, durationMinutes);
                    VDCSwitchedOn[i] = true;
                    StatusFile.AddMsg(MsgLevel.INFO,
                        $"Board {index}: Profile step {currProfile.CurrProfileStep} '{currProfile.GetCurrProfileName()}' continued. Remaining duration: {durationMinutes} min, P1 = {p1} W, P2 = {p2} W, VDC1 = {VDC1[i]} V, VDC2 = {VDC2[i]} V, R1mean = {R1mean[i]} Ohm, R2mean = {R2mean[i]} Ohm");
                }
                else
                {
                    StatusFile.AddMsg(MsgLevel.INFO,
                        $"Board {index}: Profile step {currProfile.CurrProfileStep} '{currProfile.GetCurrProfileName()}' continued.");
                }

                SelfTestRequired = true;
                SetProfileStatus(index, ProfileStatusEnum.RUNNING);
                SetNextAction(index, BurnInActionEnum.CHECK_PROFILE);
                SetStatus(index, BurnInStatusEnum.EXECUTING_PROFILE);
            }
            return ret;
        }

        public int ResetProfile(int index)
        {
            int ret = 0;
            int i = index - 1;
            var currProfile = BurnInProfiles[i];
            if (currProfile.ProfileStatus == ProfileStatusEnum.STOPPED_MANUALLY ||
                currProfile.ProfileStatus == ProfileStatusEnum.STOPPED_SHORTCIRCUIT ||
                currProfile.ProfileStatus == ProfileStatusEnum.STOPPED_ERROR ||
                currProfile.ProfileStatus == ProfileStatusEnum.FINISHED ||
                currProfile.ProfileStatus == ProfileStatusEnum.RESET_REQUESTED)
            {
                ret = 1;

                // Reset everything
                currProfile.ResetProfileTiming();
                SetProfileStatus(index, ProfileStatusEnum.READY_TO_RUN);

                VDC1[i] = 0.0;
                VDC2[i] = 0.0;
                R1mean[i] = 0.0;
                R2mean[i] = 0.0;
                VDCSwitchedOn[i] = false;
                SerialNumber[i] = "";
                NumberOfEmitters[i] = 120;
                SNrDisplayUpdateNeeded = true;
                SetStatus(index, BurnInStatusEnum.MAINBOARD_CONNECTED);
                BurnInDevs[i].SwitchOff(true);
                StatusFile.AddMsg(MsgLevel.INFO, $"Board {index}: Profile reset");
            }
            return ret;
        }

        public bool DoSelfTest()
        {
            bool status = false;
            int i = CurrActionDevice - 1;
            var dev = BurnInDevs[i];
            var currProfile = BurnInProfiles[i];

            try
            {
                // Check existence of DCDC Converter Board by checking
                // response from I2C Multiplexer on DCDC Converter Board
                status = Mbc!.CheckI2CAddr(dev.DCDCConv.MPAddr, dev.DCDCConv.Offset);
                if (!status)
                {
                    HandleSelfTestError(CurrActionDevice, $"Board {CurrActionDevice}: DC/DC Converter Board is not responding! Check connection to MBC");
                    return status;
                }

                // Check if SiC450 are responding
                status = dev.DCDCConv.CheckSiC450();
                if (!status)
                {
                    HandleSelfTestError(CurrActionDevice, $"Board {CurrActionDevice}: Problem with DC/DC Converter Board: Sic450 is not responding. Check DC power supply!");
                    return status;
                }

                // Check existence of Main Board
                status = dev.MainBoard.CheckMainBoard();
                if (!status)
                {
                    HandleSelfTestError(CurrActionDevice, $"Board {CurrActionDevice}: Problem with Main Board: Multiplexer is not responding: {dev.MainBoard.LastErrorMsg}. Check connection between DC/DC Converter and Main Board! ");
                    return status;
                }

                // Check ATtiny status
                byte attinyStatus = dev.DCDCConv.GetATtinyStatus();
                if (attinyStatus < 2)
                {
                    // ATtiny was booted or is no longer reachable
                    if (currProfile.GetStatus() == ProfileStatusEnum.RUNNING)
                    {
                        StatusFile.AddMsg(MsgLevel.WARNING, $"Board {CurrActionDevice}: Problem with Main Board: ATtiny was booted! Trying to continue...");
                        RequestNewProfileStatus(CurrActionDevice, ProfileStatusEnum.CONTINUE_REQUESTED_AFTER_ERROR);
                        if (ContinueProfile(CurrActionDevice) == 0)
                        {
                            return status;
                        }
                    }
                    else
                    {
                        status = false;
                        HandleSelfTestError(CurrActionDevice, $"Board {CurrActionDevice}: Problem with Main Board: ATtiny was booted since last connection.");
                        return status;
                    }
                }

                if (currProfile.GetStatus() == ProfileStatusEnum.RUNNING && VDCSwitchedOn[i])
                {
                    // Check if ATtiny is in correct mode
                    // Don't do this during Initial Check
                    if (currProfile.CurrProfileStep > 0)
                    {
                        ushort tSwitchOff = dev.DCDCConv.GetTimer();
                        // Do we have enough time?
                        if (tSwitchOff > 2)
                        {
                            string[] strStatus = { "Off", "On", "Blinking" };
                            var vdcSet = new double[2];
                            vdcSet[0] = VDC1[i];
                            vdcSet[1] = dev.GetNofBanks() > 1 ? VDC2[i] : 0.0;

                            for (int k = 1; k <= dev.GetNofBanks(); k++)
                            {
                                byte curStatus = dev.DCDCConv.GetVDCSwitchStatus(k);
                                (_, _, double f, _) = currProfile.GetCurrProfileElectrics(k);
                                int expectedStatus = 0;
                                if (vdcSet[k - 1] > 0)
                                {
                                    expectedStatus = f > 0 ? 2 : 1;
                                }
                                if (curStatus != expectedStatus)
                                {
                                    // fix the problem
                                    dev.DCDCConv.SwitchVDC(k, expectedStatus);
                                    StatusFile.AddMsg(MsgLevel.WARNING,
                                        $"Board {CurrActionDevice}: Problem with Main Board: For unknown reasons, the VDC{k} channel was not in mode {expectedStatus} ({strStatus[expectedStatus]}), but in mode {curStatus} ({strStatus[curStatus]}). This was automatically corrected. Please check the status file for problems and inform Andreas Neumann!");
                                }
                            }
                        }
                    }

                    // Measure VDCs if profile is running
                    var vdcSet2 = new double[2];
                    vdcSet2[0] = VDC1[i];
                    if (dev.GetNofBanks() > 1)
                    {
                        vdcSet2[1] = VDC2[i];
                    }

                    bool stopProfile = false;
                    var measurementOK = new bool[2];
                    var vdcCur = new double[2];
                    var vdcPerc = new double[2];

                    // Reset VDCmeasureStatus
                    VDC1status[i].SetVDCmeasureStatus(0);
                    if (dev.GetNofBanks() > 1)
                    {
                        VDC2status[i].SetVDCmeasureStatus(0);
                    }

                    if (VDC1status[i].GetStatus() == VDCStatusEnum.OFF_SHOULD_BE_ON)
                    {
                        stopProfile = true;
                        StatusFile.AddMsg(MsgLevel.ERROR, $"Board {CurrActionDevice}: Problem with computed VDC1: It should be greater than zero, but is zero for unknown reasons! Please inform Andreas Neumann!");
                    }
                    else if (VDC2status[i].GetStatus() == VDCStatusEnum.OFF_SHOULD_BE_ON)
                    {
                        stopProfile = true;
                        StatusFile.AddMsg(MsgLevel.ERROR, $"Board {CurrActionDevice}: Problem with computed VDC2: It should be greater than zero, but is zero for unknown reasons! Please inform Andreas Neumann!");
                    }
                    else
                    {
                        for (int k = 1; k <= dev.GetNofBanks(); k++)
                        {
                            if (vdcSet2[k - 1] > 0)
                            {
                                (measurementOK[k - 1], vdcCur[k - 1]) = dev.MeasureVDC(k);
                                if (measurementOK[k - 1])
                                {
                                    vdcPerc[k - 1] = Math.Abs(100.0 - vdcCur[k - 1] * 100.0 / vdcSet2[k - 1]);
                                    if (vdcPerc[k - 1] > MaxVDCDeviation)
                                    {
                                        StatusFile.AddMsg(MsgLevel.WARNING,
                                            $"Board {CurrActionDevice}: Problem with Main Board: VDC{k} = {vdcCur[k - 1]} V deviates by {vdcPerc[k - 1]} % from set value {vdcSet2[k - 1]} V! Doing more precise measurement!");
                                        (measurementOK[k - 1], vdcCur[k - 1]) = dev.MeasureVDCmean(k, 10);
                                        if (measurementOK[k - 1])
                                        {
                                            vdcPerc[k - 1] = Math.Abs(100.0 - vdcCur[k - 1] * 100.0 / vdcSet2[k - 1]);
                                            if (vdcPerc[k - 1] > MaxVDCDeviation)
                                            {
                                                stopProfile = true;
                                                StatusFile.AddMsg(MsgLevel.ERROR,
                                                    $"Board {CurrActionDevice}: Problem with Main Board: VDC{k} = {vdcCur[k - 1]} V deviates by {vdcPerc[k - 1]} % from set value {vdcSet2[k - 1]} V!");
                                                LogSiC450Status(k, dev);
                                                if (dev.GetNofBanks() > 1)
                                                {
                                                    int otherChannel = k == 1 ? 2 : 1;
                                                    LogSiC450Status(otherChannel, dev);
                                                }

                                                int vdcMeasureStatus = vdcCur[k - 1] > vdcSet2[k - 1] ? 1 : -1;
                                                if (k == 1)
                                                {
                                                    VDC1status[i].SetVDCmeasureStatus(vdcMeasureStatus);
                                                }
                                                else
                                                {
                                                    VDC2status[i].SetVDCmeasureStatus(vdcMeasureStatus);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if (measurementOK[0])
                    {
                        VDC1measured[i] = vdcCur[0];
                    }
                    if (dev.GetNofBanks() > 1 && measurementOK[1])
                    {
                        VDC2measured[i] = vdcCur[1];
                    }

                    if (stopProfile)
                    {
                        status = false;
                        StopProfile(CurrActionDevice, ProfileStatusEnum.STOPPED_ERROR);
                        return status;
                    }

                    status = true;
                    if (IsTimeForSelfTestResultStoring(CurrActionDevice))
                    {
                        if (measurementOK[0] || measurementOK[1])
                        {
                            var vdcMsg = new[] { "", "" };
                            var tMsg = new[] { "", "" };
                            for (int k = 1; k <= dev.GetNofBanks(); k++)
                            {
                                if (measurementOK[k - 1])
                                {
                                    vdcMsg[k - 1] = $"VDC{k}set = {vdcSet2[k - 1]} V VDC{k} = {vdcCur[k - 1]} V ({vdcPerc[k - 1]} %)";
                                }
                                double t = dev.DCDCConv.SiC450[k - 1]!.GetREAD_TEMPERATURE();
                                tMsg[k - 1] = $" T{k} = {t} \u00b0C";
                            }
                            string strSep = vdcMsg[0].Length > 0 && vdcMsg[1].Length > 0 ? "; " : "";
                            if (dev.GetNofBanks() > 1)
                            {
                                StatusFile.AddMsg(MsgLevel.INFO, $"Board {CurrActionDevice}: Self-test: {vdcMsg[0]}{tMsg[0]}{strSep}{vdcMsg[1]}{tMsg[1]}");
                            }
                            else
                            {
                                StatusFile.AddMsg(MsgLevel.INFO, $"Board {CurrActionDevice}: Self-test: {vdcMsg[0]}{tMsg[0]}");
                            }
                        }
                    }
                }
            }
            catch (Exception e)
            {
                // Which error occurred?
                if (e is InvalidOperationException || e is TimeoutException)
                {
                    // problem with one of the boards
                    HandleSelfTestError(CurrActionDevice, $"Board {CurrActionDevice}: Problem during communication with Hardware: {e.Message}.");
                }
                else
                {
                    // problem with MBC
                    HandleDisconnectedMBC(e.Message);
                }
            }

            return status;
        }

        private void LogSiC450Status(int channel, BurnInDev dev)
        {
            var sic450 = dev.DCDCConv.SiC450[channel - 1]!;
            string strStatus = $"Board {CurrActionDevice}: Status of DC/DC converter {channel}:";
            strStatus += $" STATUS_CML = 0x{sic450.GetSTATUS_CML():X}";
            strStatus += $" STATUS_WORD = 0x{sic450.GetSTATUS_WORD():X}";
            strStatus += $" STATUS_VOUT = 0x{sic450.GetSTATUS_VOUT():X}";
            strStatus += $" STATUS_INPUT = 0x{sic450.GetSTATUS_INPUT():X}";
            strStatus += $" VOUT = {sic450.GetREAD_VOUT():F3} V";
            strStatus += $" IOUT = {sic450.GetREAD_IOUT():F3} A";
            strStatus += $" VIN = {sic450.GetREAD_VIN():F3} V";
            strStatus += $" IIN = {sic450.GetREAD_IIN():F3} A";
            StatusFile.AddMsg(MsgLevel.INFO, strStatus);
        }

        public void HandleDisconnectedMBC(string errorMsg)
        {
            Console.WriteLine($"Problem with MBC: {errorMsg}");
            StatusFile.AddMsg(MsgLevel.WARNING, $"MBC disconnected! Reason: {errorMsg} Trying to reconnect...");
            if (Mbc!.TryReconnect(CurrActionDevice - 1) == 0)
            {
                Mbc.Dispose();
                Mbc = null;
                StatusFile.AddMsg(MsgLevel.ERROR, $"MBC disconnected and reconnect failed: {errorMsg}");
                MBCStatusString = "ERROR: MBC disconnected";
                for (int k = 1; k <= NumBoards; k++)
                {
                    if (BurnInProfiles[k - 1].GetStatus() == ProfileStatusEnum.RUNNING)
                    {
                        try
                        {
                            StopProfile(k, ProfileStatusEnum.STOPPED_ERROR);
                        }
                        catch (Exception e)
                        {
                            Console.WriteLine($"Exception catched during StopProfile: {e.Message}");
                        }
                    }
                    else
                    {
                        SetNextAction(k, BurnInActionEnum.DO_NOTHING);
                        SetStatus(k, BurnInStatusEnum.NO_HARDWARE_CONNECTED);
                    }
                }
            }
            else
            {
                StatusFile.AddMsg(MsgLevel.WARNING, $"MBC reconnected to {Mbc!.GetConnectedPort()}!");
                MBCStatusString = $"MBC reconnected to {Mbc.GetConnectedPort()}";
                // connection to MBC might have been lost when a multiplexer was switched on
                SwitchOffI2CMultiplexers();
                // connection to MBC might have been lost when an analog multiplexer was switched on
                DisableAllMux();
                // we simply try to continue, if something really bad happened, the SelfTest will notice!
                for (int k = 1; k <= NumBoards; k++)
                {
                    if (BurnInProfiles[k - 1].GetStatus() == ProfileStatusEnum.RUNNING)
                    {
                        RequestNewProfileStatus(k, ProfileStatusEnum.CONTINUE_REQUESTED_AFTER_ERROR);
                    }
                }
            }
        }

        public void HandleSelfTestError(int index, string errorMsg)
        {
            int i = index - 1;
            if (BurnInProfiles[i].GetStatus() >= ProfileStatusEnum.RUNNING)
            {
                if (BurnInProfiles[i].GetStatus() != ProfileStatusEnum.STOPPED_ERROR)
                {
                    StatusFile.AddMsg(MsgLevel.ERROR, errorMsg);
                    StopProfile(index, ProfileStatusEnum.STOPPED_ERROR);
                }
            }
            else
            {
                if (BurnInStatuses[i].GetStatus() != BurnInStatusEnum.NO_HARDWARE_CONNECTED)
                {
                    StatusFile.AddMsg(MsgLevel.ERROR, errorMsg);
                    SetStatus(index, BurnInStatusEnum.NO_HARDWARE_CONNECTED);
                }
                SetNextAction(index, BurnInActionEnum.DO_NOTHING);
            }
        }

        public bool IsTimeForSelfTestResultStoring(int index)
        {
            bool ret = false;
            if (Settings.StoreSelfTestResult)
            {
                int i = index - 1;
                DateTime now = DateTime.Now;
                if (_lastTimeOfSelfTestResultStorage[i].AddMinutes(Settings.StoreSelfTestResultPeriod) <= now)
                {
                    ret = true;
                    _lastTimeOfSelfTestResultStorage[i] = now;
                }
            }
            return ret;
        }

        public void ApplyRGBLEDbrightness()
        {
            for (int i = 0; i < NumBoards; i++)
            {
                BurnInDevs[i].MainBoard.BrightnessPosLEDs = Settings.BrightnessPosLEDs;
                BurnInDevs[i].MainBoard.BrightnessStatusLEDs = Settings.BrightnessStatusLEDs;
            }
        }

        public void WriteMemoryUsage(bool force)
        {
            if (Settings.StoreSelfTestResult && StoreMemConsumption)
            {
                DateTime now = DateTime.Now;
                if (_lastTimeOfMemoryAnalysis.AddMinutes(2) <= now || force)
                {
                    try
                    {
                        long memUsedBytes = Environment.WorkingSet;
                        StatusFile.AddMsg(MsgLevel.DEBUG, $"Memory used: {memUsedBytes / (1024.0 * 1024.0):F6} MB");
                    }
                    catch
                    {
                        // ignore, matches MATLAB catch-all
                    }
                    _lastTimeOfMemoryAnalysis = now;
                }
            }
        }
    }
}
