using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using ClosedXML.Excel;

namespace BurnInApp
{
    /// <summary>
    /// A single step of a burn-in profile
    /// Converted from MATLAB class by Torsten Blochwitz Electronics & Software for InfraSolid
    /// </summary>
    public class ProfileStep
    {
        public string Name { get; set; } = string.Empty;
        public TimeSpan Duration { get; set; } = TimeSpan.Zero; // Zero means it takes the time it takes
        public double[] PowerPerChannel { get; set; } = new double[2];
        public double[] MaxCurrent { get; set; } = new double[2];
        public double[] MaxVoltage { get; set; } = new double[2];
        public double[] Frequency { get; set; } = new double[2];
        public double[] DutyCycle { get; set; } = new double[2];
        public double Measure { get; set; } = 0.0; // Do at least one measurement in this step
        public int[] ComputeVDuT { get; set; } = new int[2]; // Compute VDC using Rmean to compensate Rshunt
        public double MeasurementHappened { get; set; } = 0.0; // Did a measurement happen in this step?
    }

    /// <summary>
    /// Reads and manages a burn-in profile description (Name, Duration, electrical setpoints per step)
    /// Converted from MATLAB class by Torsten Blochwitz Electronics & Software for InfraSolid
    /// </summary>
    public class BurnInProfile
    {
        // Properties
        public string FileName { get; private set; } = string.Empty;
        public string CompleteFileName { get; private set; } = string.Empty;
        public int CurrProfileStep { get; set; } = 0;
        public DateTime LastMeasurementTime { get; set; }
        public DateTime StartTime { get; set; }
        public DateTime StopTime { get; set; }
        public DateTime LastTimeCurrentStep { get; set; }
        public ProfileStatusEnum ProfileStatus { get; private set; } = ProfileStatusEnum.EMPTY;

        public List<ProfileStep> Steps { get; private set; } = new List<ProfileStep>();
        public TimeSpan[] RemainingDurationStep { get; set; } = Array.Empty<TimeSpan>();

        public string[] Type { get; private set; } = new[] { "", "" };
        public double[] NumberOfChannels { get; private set; } = new double[2];
        public double[] Resistance { get; private set; } = new double[2];
        public double[] Deviation { get; private set; } = new double[2];
        public TimeSpan MeasurementRate { get; private set; } = TimeSpan.Zero;

        private bool _lastChance4Measurement = false; // is set to true if before leaving a step, no measurement happened, but is required

        public BurnInProfile()
        {
            ResetProfileTiming();
        }

        public void ResetProfileTiming()
        {
            CurrProfileStep = 0;
            RemainingDurationStep = new TimeSpan[Steps.Count];
            for (int i = 0; i < Steps.Count; i++)
            {
                RemainingDurationStep[i] = Steps[i].Duration;
                Steps[i].MeasurementHappened = 0;
            }
            LastMeasurementTime = DateTime.Now;
        }

        /// <summary>
        /// Reads the profile from an Excel file (sheets 'Profile' and 'Data')
        /// </summary>
        /// <param name="strFile">Full path to the Excel (.xlsx) file</param>
        /// <returns>ret: true on success, false on failure; status: message describing the error, if any</returns>
        public (bool ret, string status) ReadFromExcelFile(string strFile)
        {
            bool ret = true;
            string status = string.Empty;

            Steps = new List<ProfileStep>();
            CurrProfileStep = 0;
            FileName = string.Empty;
            CompleteFileName = string.Empty;
            Type = new[] { "", "" };
            NumberOfChannels = new double[2];
            Resistance = new double[2];
            Deviation = new double[2];
            MeasurementRate = TimeSpan.Zero;

            XLWorkbook workbook;
            try
            {
                workbook = new XLWorkbook(strFile);
            }
            catch (IOException)
            {
                return (false, $"Loading {strFile} failed!\n\nThe selected profile file is currently open in another application, e.g. Microsoft Excel.\n\nPlease close the file and try again.");
            }
            catch (Exception e)
            {
                return (false, $"Loading {strFile} failed!\nError: {e.Message}.");
            }

            using (workbook)
            {
                IXLWorksheet? profileSheet = null;
                IXLWorksheet? dataSheet = null;
                try
                {
                    profileSheet = workbook.Worksheet("Profile");
                    dataSheet = workbook.Worksheet("Data");
                }
                catch (Exception e)
                {
                    return (false, $"Loading {strFile} failed!\nError: {e.Message}.");
                }

                var profileRows = ReadTable(profileSheet);
                int rowIndex = 0;
                try
                {
                    foreach (var row in profileRows)
                    {
                        rowIndex++;
                        var step = new ProfileStep
                        {
                            Name = GetString(row, "Name"),
                            // Duration is stored in Excel as a duration (fraction of a day)
                            Duration = TimeSpan.FromDays(GetDouble(row, "Duration"))
                        };
                        step.PowerPerChannel[0] = GetDouble(row, "PowerPerChannel1");
                        step.MaxCurrent[0] = GetDouble(row, "MaxCurrent1");
                        step.MaxVoltage[0] = GetDouble(row, "MaxVoltage1");
                        step.Frequency[0] = GetDouble(row, "Frequency1");
                        step.DutyCycle[0] = GetDouble(row, "DutyCycle1");
                        step.PowerPerChannel[1] = GetDouble(row, "PowerPerChannel2");
                        step.MaxCurrent[1] = GetDouble(row, "MaxCurrent2");
                        step.MaxVoltage[1] = GetDouble(row, "MaxVoltage2");
                        step.Frequency[1] = GetDouble(row, "Frequency2");
                        step.DutyCycle[1] = GetDouble(row, "DutyCycle2");
                        // if the Excel Sheet does not contain the ComputeVDuT1/2 column, default to 0
                        step.ComputeVDuT[0] = row.ContainsKey("ComputeVDuT1") ? (int)GetDouble(row, "ComputeVDuT1") : 0;
                        step.ComputeVDuT[1] = row.ContainsKey("ComputeVDuT2") ? (int)GetDouble(row, "ComputeVDuT2") : 0;
                        // if the Excel Sheet does not contain the Measure column, default to 0.0
                        step.Measure = row.ContainsKey("Measure") ? GetDouble(row, "Measure") : 0.0;
                        step.MeasurementHappened = 0;
                        Steps.Add(step);
                    }
                }
                catch (Exception e)
                {
                    return (false, $"Error: Loading {strFile} failed!\nError in row {rowIndex}: {e.Message}.");
                }

                // check durations
                RemainingDurationStep = new TimeSpan[Steps.Count];
                for (int i = 0; i < Steps.Count; i++)
                {
                    double minutes = Steps[i].Duration.TotalMinutes;
                    if (minutes > 65535)
                    {
                        return (false, $"Error: Loading {strFile} failed!\n\nError in row {i + 1}: Duration of {minutes} min is larger than 65535 min. This is not supported!\n\nSplit this profile step into steps with smaller durations!");
                    }
                    RemainingDurationStep[i] = Steps[i].Duration;
                }

                var dataRows = ReadTable(dataSheet);
                var dataRow = dataRows.FirstOrDefault();
                if (dataRow == null)
                {
                    return (false, $"Loading {strFile} failed!\nError in Sheet 'Data': sheet is empty.");
                }
                try
                {
                    Type[0] = GetString(dataRow, "Type1");
                    NumberOfChannels[0] = GetDouble(dataRow, "NumberOfChannels1");
                    Resistance[0] = GetDouble(dataRow, "Resistance1");
                    Deviation[0] = GetDouble(dataRow, "Deviation1");
                    Type[1] = GetString(dataRow, "Type2");
                    NumberOfChannels[1] = GetDouble(dataRow, "NumberOfChannels2");
                    Resistance[1] = GetDouble(dataRow, "Resistance2");
                    Deviation[1] = GetDouble(dataRow, "Deviation2");
                    MeasurementRate = TimeSpan.FromMinutes(GetDouble(dataRow, "MeasurementRate"));
                }
                catch (Exception e)
                {
                    return (false, $"Loading {strFile} failed!\nError in Sheet 'Data': {e.Message}.");
                }

                if (GetNoSteps() > 0)
                {
                    FileName = Path.GetFileName(strFile);
                    CompleteFileName = strFile;
                    ProfileStatus = ProfileStatusEnum.READY_TO_RUN;
                }
                else
                {
                    Steps = new List<ProfileStep>();
                    return (false, $"Error: The file {strFile} does not contain profile data.");
                }
            }

            return (ret, status);
        }

        /// <summary>
        /// Reads a worksheet as a list of rows, each row mapping column header (row 1) to cell value.
        /// Mirrors MATLAB's readtable behavior of accessing columns by name.
        /// </summary>
        private static List<Dictionary<string, IXLCell>> ReadTable(IXLWorksheet sheet)
        {
            var result = new List<Dictionary<string, IXLCell>>();
            IXLRange? usedRange = sheet.RangeUsed();
            if (usedRange == null)
            {
                return result;
            }

            var headerRow = usedRange.FirstRow();
            var headers = new Dictionary<int, string>();
            foreach (var cell in headerRow.Cells())
            {
                string header = cell.GetString().Trim();
                if (!string.IsNullOrEmpty(header))
                {
                    headers[cell.Address.ColumnNumber] = header;
                }
            }

            var dataRows = usedRange.Rows().Skip(1);
            foreach (var row in dataRows)
            {
                var rowDict = new Dictionary<string, IXLCell>();
                foreach (var (columnNumber, header) in headers)
                {
                    rowDict[header] = row.Cell(columnNumber - usedRange.FirstColumn().ColumnNumber() + 1);
                }
                // skip completely empty rows
                if (rowDict.Values.All(c => c.IsEmpty()))
                {
                    continue;
                }
                result.Add(rowDict);
            }

            return result;
        }

        private static double GetDouble(Dictionary<string, IXLCell> row, string column)
        {
            if (!row.TryGetValue(column, out var cell))
            {
                throw new KeyNotFoundException($"Column '{column}' not found.");
            }
            return cell.GetValue<double>();
        }

        private static string GetString(Dictionary<string, IXLCell> row, string column)
        {
            if (!row.TryGetValue(column, out var cell))
            {
                throw new KeyNotFoundException($"Column '{column}' not found.");
            }
            return cell.GetString();
        }

        public int GetNoSteps()
        {
            return Steps.Count;
        }

        public TimeSpan GetDuration()
        {
            TimeSpan dur = TimeSpan.Zero;
            for (int i = 0; i < Steps.Count; i++)
            {
                if (ProfileStatus == ProfileStatusEnum.RUNNING)
                {
                    if (RemainingDurationStep.Length <= i)
                    {
                        dur += Steps[i].Duration;
                    }
                    else
                    {
                        dur += RemainingDurationStep[i];
                    }
                }
                else
                {
                    dur += Steps[i].Duration;
                }
            }
            if (ProfileStatus != ProfileStatusEnum.RUNNING)
            {
                // add estimated duration for initial measurements
                dur += TimeSpan.FromMinutes(10);
            }
            return dur;
        }

        public string GetFileName() => FileName;

        public string GetCompleteFileName() => CompleteFileName;

        public bool IsProfileLoaded()
        {
            return !string.IsNullOrEmpty(FileName);
        }

        public int GetMaxNofEmitters()
        {
            if (!IsProfileLoaded())
            {
                return 0;
            }
            return (int)(NumberOfChannels[0] + NumberOfChannels[1]);
        }

        public string GetCurrProfileName()
        {
            if (CurrProfileStep < 1)
            {
                string name = "Initial checks";
                if (GetNoSteps() > 0 && Steps[0].Name == "Skip initial check")
                {
                    name = Steps[0].Name;
                }
                return name;
            }
            return Steps[CurrProfileStep - 1].Name;
        }

        public string GetCurrName()
        {
            string str = "";
            if (CurrProfileStep > GetNoSteps())
            {
                return "Unknown";
            }

            str = ProfileStatus switch
            {
                ProfileStatusEnum.RUNNING => "",
                ProfileStatusEnum.RUN_REQUESTED => ": Start requested.",
                ProfileStatusEnum.STOP_REQUESTED_ERROR => ": Stop (Error) requested!",
                ProfileStatusEnum.STOP_REQUESTED_MANUALLY => ": Stop requested.",
                ProfileStatusEnum.CONTINUE_REQUESTED_AFTER_ERROR => ": Continue requested",
                ProfileStatusEnum.CONTINUE_REQUESTED => ": Continue requested",
                ProfileStatusEnum.RESET_REQUESTED => ": Reset requested.",
                ProfileStatusEnum.STOPPED_MANUALLY => ": Stopped manually!",
                ProfileStatusEnum.STOPPED_ERROR => ": Stopped because of an Error!",
                ProfileStatusEnum.STOPPED_SHORTCIRCUIT => ": Shortcut! Remove marked Emitters!",
                ProfileStatusEnum.FINISHED => ": Finished!",
                _ => ""
            };

            string name = GetCurrProfileName();
            return $"{name}{str}";
        }

        public ProfileStatusEnum GetStatus() => ProfileStatus;

        public void SetStatus(ProfileStatusEnum status)
        {
            ProfileStatus = status;
        }

        public (double p, double v, double f, double dutyCycle) GetCurrProfileElectrics(int n)
        {
            int index = Math.Max(CurrProfileStep - 1, 0);
            if (CurrProfileStep <= GetNoSteps())
            {
                var step = Steps[index];
                return (step.PowerPerChannel[n - 1], step.MaxVoltage[n - 1], step.Frequency[n - 1], step.DutyCycle[n - 1]);
            }
            return (0, 0, 0, 0);
        }

        public (string strMsg, VDCStatusEnum vdcStatus, double v) GetCurrVoltage(int n, double rMean, double numberOfEmitters)
        {
            string strMsg = "";
            VDCStatusEnum vdcStatus = VDCStatusEnum.UNKNOWN;
            double v = 0;
            int index = Math.Max(CurrProfileStep - 1, 0);

            if (CurrProfileStep > GetNoSteps())
            {
                return (strMsg, vdcStatus, v);
            }

            var step = Steps[index];
            int ch = n - 1;

            if (n == 2 && numberOfEmitters <= NumberOfChannels[0])
            {
                // less than maximum possible emitters on first bank -> switch off VDC2 if no emitters
                strMsg = $"VDC{n} = 0 V, OFF (no emitters plugged in).";
                return (strMsg, VDCStatusEnum.OFF_OK, 0);
            }
            else if (step.PowerPerChannel[ch] == 0.0 && step.MaxVoltage[ch] == 0.0)
            {
                strMsg = $"VDC{n} = 0 V, OFF (PowerPerChannel = 0.0 W,MaxVoltage = 0.0 V).";
                return (strMsg, VDCStatusEnum.OFF_OK, 0);
            }
            else if (step.PowerPerChannel[ch] == 0.0 && step.MaxVoltage[ch] > 0.0)
            {
                // use MaxVoltage
                v = step.MaxVoltage[ch];
                vdcStatus = VDCStatusEnum.ON_OK_V_CONTROLED;
                strMsg = $"VDC{n} = {v} V (using MaxVoltage).";
                if (step.ComputeVDuT[ch] == 1)
                {
                    if (rMean > 0.0)
                    {
                        v = v * (0.82 + rMean) / rMean;
                        strMsg = $"{strMsg} VDC{n} adjusted to {v} V to compensate shunt!";
                    }
                    else
                    {
                        strMsg = $"{strMsg} VDC{n} could not be adjusted to compensate shunt, because Rmean == 0 Ohm!";
                    }
                }
            }
            else if (rMean > 0.0)
            {
                // use PowerPerChannel
                v = Math.Sqrt(Math.Abs(step.PowerPerChannel[ch]) * rMean);
                strMsg = $"VDC{n} = {v} V (using PowerPerChannel = {step.PowerPerChannel[ch]} W, Rmean = {rMean} Ohm).";
                vdcStatus = VDCStatusEnum.ON_OK_P_CONTROLED;
                if (v > step.MaxVoltage[ch])
                {
                    v = Math.Min(v, step.MaxVoltage[ch]);
                    strMsg = $"{strMsg} VDC{n} reduced to MaxVoltage = {v} V.";
                    vdcStatus = VDCStatusEnum.ON_PCONTROLED_V_LIMIT;
                }
                if (v / rMean > step.MaxCurrent[ch])
                {
                    v = rMean * step.MaxCurrent[ch];
                    strMsg = $"{strMsg} VDC{n} reduced to {v} V (MaxCurrent = {step.MaxCurrent[ch]} was exceeded!).";
                    vdcStatus = VDCStatusEnum.ON_PCONTROLED_I_LIMIT;
                }
                if (step.ComputeVDuT[ch] == 1)
                {
                    v = v * (0.82 + rMean) / rMean;
                    strMsg = $"{strMsg} VDC{n} adjusted to {v} V to compensate shunt!";
                }
                if (v > 0.0 && v < 0.3)
                {
                    strMsg = $"{strMsg} VDC{n} increased to 0.3 V which is the minimum value!";
                    v = 0.3;
                }
            }
            else
            {
                vdcStatus = VDCStatusEnum.OFF_SHOULD_BE_ON;
                strMsg = $"VDC{n} = 0 V (VDC cannot be computed using PowerPerChannel because measured Rmean = 0 Ohm).";
                v = 0;
            }

            // should not happen, but just to make sure and find out what happened
            if (!(step.PowerPerChannel[ch] > 0.0 && step.MaxVoltage[ch] > 0.0) && v == 0)
            {
                vdcStatus = VDCStatusEnum.OFF_SHOULD_BE_ON;
                strMsg = $"VDC{n} = 0 V for unknown reasons! ({strMsg})";
            }
            else
            {
                strMsg = $"VDC{n} = {v} V. ({strMsg})";
            }

            return (strMsg, vdcStatus, v);
        }

        public double GetCurrMeasurementMode()
        {
            if (CurrProfileStep == 0)
            {
                return 0;
            }
            return Steps[CurrProfileStep - 1].Measure;
        }

        public ushort GetCurrDurationMinutes()
        {
            return (ushort)Steps[CurrProfileStep - 1].Duration.TotalMinutes;
        }

        public ushort GetRemainingDurationStepMinutes()
        {
            return (ushort)RemainingDurationStep[CurrProfileStep - 1].TotalMinutes;
        }

        public bool IsTimeForMeasurement()
        {
            bool ret = false;
            if (ProfileStatus == ProfileStatusEnum.RUNNING && MeasurementRate > TimeSpan.Zero)
            {
                DateTime now = DateTime.Now;
                if (LastMeasurementTime + MeasurementRate <= now)
                {
                    ret = true;
                }
            }
            if (ProfileStatus == ProfileStatusEnum.RUNNING && _lastChance4Measurement)
            {
                var step = Steps[CurrProfileStep - 1];
                if (step.Measure > 0 && step.MeasurementHappened < 1)
                {
                    ret = true;
                    _lastChance4Measurement = false;
                }
            }
            return ret;
        }

        public void SetMeasurementHappendInCurrentProfileStep()
        {
            if (CurrProfileStep > 0)
            {
                Steps[CurrProfileStep - 1].MeasurementHappened = 1;
            }
        }

        public void SetLastChance4Measurement()
        {
            _lastChance4Measurement = true;
        }
    }
}
