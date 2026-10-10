using BurnIn.Shared;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Text;

namespace BurnInBoardMaintenanceApp
{
    internal sealed class BoardMaintenanceController : IDisposable
    {
        private const string AppName = "BurnIn Board Maintenance App";
        private const string Version = "3.2.2";

        private string _mbcStatus = string.Empty;
        private string _dcdcStatus = string.Empty;
        private string _mainBoardStatus = string.Empty;

        public BurnInSettings Settings { get; }
        public BurnInDev BurnInDevice { get; } = new();
        public MBC_TB? Mbc { get; private set; }

        public string DcdcUuid { get; private set; } = string.Empty;
        public string DcdcSoftwareVersion { get; private set; } = string.Empty;
        public string MainBoardUuid { get; private set; } = string.Empty;
        public ObservableCollection<DcdcStatusRow> DcdcStatusRows { get; } =
        [
            new DcdcStatusRow { Channel = "VDC1" },
            new DcdcStatusRow { Channel = "VDC2" }
        ];

        public BoardMaintenanceController()
        {
            string settingsPath = Path.Combine(
                BurnInSharedContext.GetConfigDirectory(),
                "BurnInBoardMaintenanceSettings.json");
            Settings = new BurnInSettings(settingsPath);
            Settings.Folder = Path.Combine(BurnInSharedContext.GetDataDirectory(), "Measurements");
            Settings.Postfix = string.IsNullOrWhiteSpace(Settings.Postfix) ? "Maintenance" : Settings.Postfix;
        }

        public string GetAppTitle()
        {
            return $"{AppName} (Version: {Version})";
        }

        public bool IsMbcConnected => Mbc != null;
        public bool IsDcdcConnected => BurnInDevice.DCDCConv.Status > 0;
        public bool IsMainBoardConnected => BurnInDevice.MainBoard.Status > 0;
        public int ChannelCount => Math.Max(1, BurnInDevice.DCDCConv.NChannels);
        public bool SupportsSecondChannel => BurnInDevice.DCDCConv.NChannels > 1;
        public string StatusText => string.Concat(_mbcStatus, _dcdcStatus, _mainBoardStatus);

        public IEnumerable<string> GetI2cOffsetItems()
        {
            return Enumerable.Range(0, 8).Select(i => i.ToString());
        }

        public IEnumerable<string> GetMuxOptions()
        {
            int numberOfChannels = Math.Max(60 * ChannelCount, 60);
            var items = new List<string> { "Disable" };
            items.AddRange(Enumerable.Range(1, numberOfChannels).Select(i => i.ToString()));
            items.Add("VDC1");
            if (SupportsSecondChannel)
            {
                items.Add("VDC2");
            }
            return items;
        }

        public bool ConnectMbc(string address)
        {
            _mbcStatus = string.Empty;
            _dcdcStatus = string.Empty;
            _mainBoardStatus = string.Empty;

            try
            {
                Mbc?.Dispose();
                Mbc = new MBC_TB(address);
                Settings.MBC_Port = address;

                if (Mbc.Mode == MBCModeEnum.TCP)
                {
                    Settings.I2CAddrOffset = 0;
                    Mbc.ConnectToTCPServer(Settings.I2CAddrOffset, address, 10);
                }

                Mbc.Reset();
                BurnInDevice.UpdateRefToMBC(Mbc);
                _mbcStatus = string.Empty;
                return true;
            }
            catch (Exception ex)
            {
                _mbcStatus = $"Could not connect to MBC on {address}: {ex.Message}{Environment.NewLine}{Environment.NewLine}";
                Mbc?.Dispose();
                Mbc = null;
                return false;
            }
        }

        public bool ConnectBoards(int offset)
        {
            Settings.I2CAddrOffset = offset;
            _dcdcStatus = string.Empty;
            _mainBoardStatus = string.Empty;

            if (Mbc == null)
            {
                _mbcStatus = "MBC is not connected." + Environment.NewLine + Environment.NewLine;
                return false;
            }

            try
            {
                if (Mbc.Mode == MBCModeEnum.TCP)
                {
                    Settings.I2CAddrOffset = 0;
                    offset = 0;
                }

                int result = BurnInDevice.ConnectBoards(Mbc, offset);
                RefreshBoardMetadata();
                RefreshDcdcStatus();

                if (result <= 0)
                {
                    _dcdcStatus = $"Problem during connecting to DC/DC Converter Board with address offset {offset}: {BurnInDevice.DCDCConv.LastErrorMsg}{Environment.NewLine}";
                    _mainBoardStatus = string.Empty;
                    return false;
                }

                if (!IsMainBoardConnected)
                {
                    _mainBoardStatus = $"Problem during connecting to Main Board with address offset {offset}: {BurnInDevice.MainBoard.LastErrorMsg}{Environment.NewLine}";
                }

                return true;
            }
            catch (Exception ex)
            {
                _dcdcStatus = $"Problem during connecting to boards with address offset {offset}: {ex.Message}{Environment.NewLine}";
                return false;
            }
        }

        public void RefreshBoardMetadata()
        {
            try
            {
                DcdcUuid = IsDcdcConnected ? BurnInDevice.DCDCConv.GetUUIDString() : string.Empty;
                DcdcSoftwareVersion = IsDcdcConnected ? BurnInDevice.DCDCConv.GetSWVersionString() : string.Empty;
            }
            catch
            {
                DcdcUuid = string.Empty;
                DcdcSoftwareVersion = string.Empty;
            }

            try
            {
                MainBoardUuid = IsMainBoardConnected ? BurnInDevice.MainBoard.EEPROM?.GetUUIDString() ?? string.Empty : string.Empty;
            }
            catch
            {
                MainBoardUuid = string.Empty;
            }
        }

        public void RefreshDcdcStatus()
        {
            for (int channel = 1; channel <= DcdcStatusRows.Count; channel++)
            {
                DcdcStatusRow row = DcdcStatusRows[channel - 1];
                if (!IsDcdcConnected || channel > BurnInDevice.DCDCConv.NChannels || BurnInDevice.DCDCConv.SiC450[channel - 1] == null)
                {
                    row.Cml = "n/a";
                    row.Word = "n/a";
                    row.VoutStatus = "n/a";
                    row.InputStatus = "n/a";
                    row.Vdc = "n/a";
                    row.Iout = "n/a";
                    row.Vin = "n/a";
                    row.Iin = "n/a";
                    row.Temperature = "n/a";
                    continue;
                }

                PMBusDev dev = BurnInDevice.DCDCConv.SiC450[channel - 1]!;
                row.Cml = $"0x{dev.GetSTATUS_CML():X}";
                row.Word = $"0x{dev.GetSTATUS_WORD():X}";
                row.VoutStatus = $"0x{dev.GetSTATUS_VOUT():X}";
                row.InputStatus = $"0x{dev.GetSTATUS_INPUT():X}";
                row.Vdc = dev.GetREAD_VOUT().ToString("F3");
                row.Iout = dev.GetREAD_IOUT().ToString("F3");
                row.Vin = dev.GetREAD_VIN().ToString("F3");
                row.Iin = dev.GetREAD_IIN().ToString("F3");
                row.Temperature = dev.GetREAD_TEMPERATURE().ToString("F3");
            }
        }

        public bool TrySetMainBoardUuid(string value, out string errorMessage)
        {
            errorMessage = string.Empty;
            if (!TryValidateUuid(value, out string normalized, out errorMessage))
            {
                return false;
            }

            bool result = BurnInDevice.MainBoard.EEPROM?.SetUUIDString(normalized) ?? false;
            RefreshBoardMetadata();
            if (!result)
            {
                errorMessage = "Error writing UUID. Please check the write access jumper.";
            }
            return result;
        }

        public bool TrySetDcdcUuid(string value, out string errorMessage)
        {
            errorMessage = string.Empty;
            if (!TryValidateUuid(value, out string normalized, out errorMessage))
            {
                return false;
            }

            bool result = BurnInDevice.DCDCConv.SetUUIDString(normalized);
            RefreshBoardMetadata();
            if (!result)
            {
                errorMessage = "Error writing UUID of DCDC Board.";
            }
            return result;
        }

        public static bool TryValidateUuid(string value, out string normalized, out string errorMessage)
        {
            normalized = (value ?? string.Empty).Replace("-", string.Empty).Trim();
            errorMessage = string.Empty;

            if (normalized.Length != 32)
            {
                errorMessage = "The entered UUID must contain exactly 16 hex values (32 hex digits).";
                return false;
            }

            for (int i = 0; i < normalized.Length; i++)
            {
                if (!Uri.IsHexDigit(normalized[i]))
                {
                    errorMessage = $"Error in UUID: '{normalized[i]}' is not a valid hex digit.";
                    return false;
                }
            }

            return true;
        }

        public bool TrySetVdc(int channel, double value)
        {
            return IsDcdcConnected && BurnInDevice.DCDCConv.SetSiC450_Voltage(channel, value);
        }

        public bool TrySetFrequencyDuty(int channel, double frequency, byte dutyCycle)
        {
            return IsDcdcConnected && BurnInDevice.DCDCConv.SetFrequDutyBank(channel, frequency, dutyCycle);
        }

        public bool TrySwitchVdc(int channel, int state)
        {
            return IsDcdcConnected && BurnInDevice.DCDCConv.SwitchVDC(channel, state);
        }

        public bool TrySwitchDcdcStatusLed(int state)
        {
            return IsDcdcConnected && BurnInDevice.DCDCConv.SwitchStatusLED_DCDC(state);
        }

        public bool TryClearFaults(int channel)
        {
            if (!IsDcdcConnected || BurnInDevice.DCDCConv.SiC450[channel - 1] == null)
            {
                return false;
            }

            BurnInDevice.DCDCConv.SiC450[channel - 1]!.SetCLEAR_FAULTS();
            return true;
        }

        public bool TryStoreDefaults(int channel)
        {
            return IsDcdcConnected && BurnInDevice.DCDCConv.SetSiC450_StoreDefaults(channel);
        }

        public bool TrySetTimer(ushort value)
        {
            return IsDcdcConnected && BurnInDevice.DCDCConv.SetTimer(value);
        }

        public ushort GetTimer()
        {
            return IsDcdcConnected ? BurnInDevice.DCDCConv.GetTimer() : (ushort)0;
        }

        public bool TrySetAttinyStatus(byte value)
        {
            return IsDcdcConnected && BurnInDevice.DCDCConv.SetATtinyStatus(value);
        }

        public byte GetAttinyStatus()
        {
            return IsDcdcConnected ? BurnInDevice.DCDCConv.GetATtinyStatus() : (byte)0;
        }

        public bool TrySwitchMainBoardStatusLed(bool isOn)
        {
            return IsMainBoardConnected && BurnInDevice.MainBoard.SwitchStatusLED(isOn ? 1 : 0) >= 0;
        }

        public double[] ReadTemperatures()
        {
            var values = new double[3];
            for (int i = 0; i < values.Length; i++)
            {
                values[i] = BurnInDevice.MainBoard.TempSensor[i]?.GetTemperatureCelsius() ?? double.NaN;
            }
            return values;
        }

        public MeasurementSnapshot MeasureSingle(string muxSelection)
        {
            var snapshot = new MeasurementSnapshot();
            if (!IsMainBoardConnected)
            {
                return snapshot;
            }

            if (string.Equals(muxSelection, "VDC1", StringComparison.OrdinalIgnoreCase))
            {
                var (status, vdc) = BurnInDevice.MeasureVDC(1);
                snapshot.AdcVoltage = status ? vdc : double.PositiveInfinity;
                return snapshot;
            }

            if (string.Equals(muxSelection, "VDC2", StringComparison.OrdinalIgnoreCase))
            {
                var (status, vdc) = BurnInDevice.MeasureVDC(2);
                snapshot.AdcVoltage = status ? vdc : double.PositiveInfinity;
                return snapshot;
            }

            if (int.TryParse(muxSelection, out int channel))
            {
                int zeroBasedChannel = Math.Max(0, channel - 1);
                var (resistance, vdc, _) = BurnInDevice.MeasR(zeroBasedChannel, 5);
                snapshot.AdcResistance = resistance;
                snapshot.AdcVoltage = vdc;
            }

            return snapshot;
        }

        public void SetMux(string muxSelection)
        {
            if (!IsMainBoardConnected)
            {
                return;
            }

            if (string.Equals(muxSelection, "Disable", StringComparison.OrdinalIgnoreCase))
            {
                BurnInDevice.MainBoard.SetMUX(-1);
            }
            else if (string.Equals(muxSelection, "VDC1", StringComparison.OrdinalIgnoreCase))
            {
                BurnInDevice.MainBoard.SetMUX(BurnInDevice.GetVDCChannel(1));
            }
            else if (string.Equals(muxSelection, "VDC2", StringComparison.OrdinalIgnoreCase))
            {
                BurnInDevice.MainBoard.SetMUX(BurnInDevice.GetVDCChannel(2));
            }
            else if (int.TryParse(muxSelection, out int channel))
            {
                BurnInDevice.MainBoard.SetMUX(channel - 1);
            }
        }

        public void SetRgbLed(int ledIndex, int red, int green, int blue, bool switchOffOthers, bool applyImmediately)
        {
            if (!IsMainBoardConnected)
            {
                return;
            }

            BurnInDevice.MainBoard.SwitchRGBLED(ledIndex, red, green, blue, switchOffOthers, applyImmediately);
        }

        public void RunLightShow()
        {
            if (!IsMainBoardConnected)
            {
                return;
            }

            BurnInDevice.MainBoard.SwitchRGBLED(0, 0, 0, 0, true, true);
            for (int led = 1; led <= BurnInDevice.GetMaxNofEmitters(); led++)
            {
                BurnInDevice.MainBoard.SwitchRGBLED(led, 255, 64, 64, false, false);
            }
            BurnInDevice.MainBoard.SwitchRGBLED(0, 0, 0, 0, false, true);
        }

        public void SaveSettings()
        {
            Settings.SaveToFile(Settings.FileName);
        }

        public void Dispose()
        {
            try
            {
                SaveSettings();
            }
            catch
            {
            }

            try
            {
                BurnInDevice.MainBoard.SetMUX(-1);
            }
            catch
            {
            }

            try
            {
                BurnInDevice.DCDCConv.SwitchOff();
            }
            catch
            {
            }

            Mbc?.Dispose();
        }
    }
}
