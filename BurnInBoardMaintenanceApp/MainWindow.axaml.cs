using Avalonia;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Platform.Storage;
using Avalonia.Threading;
using System;
using System.Threading.Tasks;

namespace BurnInBoardMaintenanceApp
{
    public partial class MainWindow : Window
    {
        private readonly BoardMaintenanceController _controller;
        private readonly DispatcherTimer _measurementTimer;
        private double _measurementCountdownMinutes;

        public MainWindow()
        {
            InitializeComponent();
            _controller = new BoardMaintenanceController();
            _measurementTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
            _measurementTimer.Tick += MeasurementTimer_Tick;
            Title = _controller.GetAppTitle();

            I2cOffsetComboBox.ItemsSource = _controller.GetI2cOffsetItems();
            MuxComboBox.ItemsSource = _controller.GetMuxOptions();
            DcdcStatusGrid.ItemsSource = _controller.DcdcStatusRows;

            MbcAddressTextBox.Text = _controller.Settings.MBC_Port;
            I2cOffsetComboBox.SelectedItem = _controller.Settings.I2CAddrOffset.ToString();
            FolderTextBox.Text = _controller.Settings.Folder;
            PostfixTextBox.Text = _controller.Settings.Postfix;

            Vdc1Numeric.Value = 3;
            Vdc2Numeric.Value = 3;
            Frequency1Numeric.Value = 1;
            Frequency2Numeric.Value = 1;
            DutyCycle1Numeric.Value = 50;
            DutyCycle2Numeric.Value = 50;
            SwitchOffTimerNumeric.Value = 10;
            RgbLedIndexNumeric.Value = 1;
            RedNumeric.Value = 32;
            GreenNumeric.Value = 32;
            BlueNumeric.Value = 32;
            MeasureEveryNumeric.Value = 1;
            ApplyImmediatelyCheckBox.IsChecked = true;
            SwitchOffOthersCheckBox.IsChecked = true;

            SwitchVdc1OffRadio.IsChecked = true;
            SwitchVdc2OffRadio.IsChecked = true;
            DcdcStatusLedOffRadio.IsChecked = true;

            UpdateUiState();
        }

        private void MeasurementTimer_Tick(object? sender, EventArgs e)
        {
            _measurementCountdownMinutes = Math.Max(0, _measurementCountdownMinutes - (1.0 / 60.0));
            if (_measurementCountdownMinutes <= 0)
            {
                TimerMeasurementStatusTextBlock.Text = "Periodic measurement trigger reached. Detailed measurement workflow is not ported yet.";
                _measurementCountdownMinutes = Convert.ToDouble(MeasureEveryNumeric.Value);
            }
            else
            {
                TimerMeasurementStatusTextBlock.Text = $"Next measurement in {_measurementCountdownMinutes:F1} min";
            }
        }

        private void MainWindow_Closing(object? sender, WindowClosingEventArgs e)
        {
            _controller.Settings.MBC_Port = MbcAddressTextBox.Text?.Trim() ?? string.Empty;
            _controller.Settings.Folder = FolderTextBox.Text?.Trim() ?? string.Empty;
            _controller.Settings.Postfix = PostfixTextBox.Text?.Trim() ?? string.Empty;
            _controller.Dispose();
        }

        private void SetIndicator(Border indicator, bool isConnected)
        {
            indicator.Background = isConnected ? Brushes.LightGreen : Brushes.IndianRed;
        }

        private void SetIndicator(Border indicator, IBrush brush)
        {
            indicator.Background = brush;
        }

        private void UpdateUiState()
        {
            SetIndicator(MbcStatusIndicator, _controller.IsMbcConnected);
            SetIndicator(DcdcStatusIndicator, _controller.IsDcdcConnected);
            SetIndicator(MainBoardStatusIndicator, _controller.IsMainBoardConnected);

            ConnectBoardsButton.IsEnabled = _controller.IsMbcConnected;
            CommunicationSettingsButton.IsEnabled = _controller.IsMbcConnected && _controller.Mbc?.Mode == BurnIn.Shared.MBCModeEnum.TCP;

            bool dcdcEnabled = _controller.IsDcdcConnected;
            bool mainEnabled = _controller.IsMainBoardConnected;

            Vdc1Numeric.IsEnabled = dcdcEnabled;
            Frequency1Numeric.IsEnabled = dcdcEnabled;
            DutyCycle1Numeric.IsEnabled = dcdcEnabled;
            SwitchVdc1OffRadio.IsEnabled = dcdcEnabled;
            SwitchVdc1OnRadio.IsEnabled = dcdcEnabled;
            SwitchVdc1BlinkRadio.IsEnabled = dcdcEnabled;
            Vdc2Numeric.IsEnabled = dcdcEnabled && _controller.SupportsSecondChannel;
            Frequency2Numeric.IsEnabled = dcdcEnabled && _controller.SupportsSecondChannel;
            DutyCycle2Numeric.IsEnabled = dcdcEnabled && _controller.SupportsSecondChannel;
            SwitchVdc2OffRadio.IsEnabled = dcdcEnabled && _controller.SupportsSecondChannel;
            SwitchVdc2OnRadio.IsEnabled = dcdcEnabled && _controller.SupportsSecondChannel;
            SwitchVdc2BlinkRadio.IsEnabled = dcdcEnabled && _controller.SupportsSecondChannel;

            SingleMeasurementButton.IsEnabled = mainEnabled;
            MeasurementDialogButton.IsEnabled = mainEnabled;
            MainBoardStatusLedCheckBox.IsEnabled = mainEnabled;
            MuxComboBox.IsEnabled = mainEnabled;
            SetFolderButton.IsEnabled = mainEnabled;
            SkipTimerButton.IsEnabled = PeriodicMeasurementToggle.IsChecked == true;
            MeasureEveryNumeric.IsEnabled = PeriodicMeasurementToggle.IsChecked != true;

            MuxComboBox.ItemsSource = _controller.GetMuxOptions();
            if (MuxComboBox.SelectedItem == null)
            {
                MuxComboBox.SelectedItem = "Disable";
            }

            DcdcVersionTextBox.Text = _controller.DcdcSoftwareVersion;
            DcdcUuidTextBox.Text = _controller.DcdcUuid;
            MainUuidTextBox.Text = _controller.MainBoardUuid;
            StatusTextBox.Text = _controller.StatusText;
        }

        private static bool TryGetSwitchState(object? sender, out int state)
        {
            state = 0;
            if (sender is RadioButton radioButton && radioButton.IsChecked == true)
            {
                return int.TryParse(radioButton.Tag?.ToString(), out state);
            }

            return false;
        }

        private void ApplyDcdcChannel(int channel)
        {
            double voltage = channel == 1
                ? Convert.ToDouble(Vdc1Numeric.Value)
                : Convert.ToDouble(Vdc2Numeric.Value);
            double frequency = channel == 1
                ? Convert.ToDouble(Frequency1Numeric.Value)
                : Convert.ToDouble(Frequency2Numeric.Value);
            byte dutyCycle = (byte)(channel == 1
                ? Convert.ToInt32(DutyCycle1Numeric.Value)
                : Convert.ToInt32(DutyCycle2Numeric.Value));

            _controller.TrySetVdc(channel, voltage);
            _controller.TrySetFrequencyDuty(channel, frequency, dutyCycle);
            _controller.RefreshDcdcStatus();
            UpdateUiState();
        }

        private async Task ShowMessageAsync(string title, string message)
        {
            var dialog = new Window
            {
                Title = title,
                Width = 420,
                Height = 180,
                WindowStartupLocation = WindowStartupLocation.CenterOwner,
                CanResize = false
            };

            var panel = new StackPanel
            {
                Margin = new Thickness(16),
                Spacing = 12
            };

            panel.Children.Add(new TextBlock
            {
                Text = message,
                TextWrapping = TextWrapping.Wrap
            });

            var button = new Button
            {
                Content = "OK",
                HorizontalAlignment = HorizontalAlignment.Center,
                MinWidth = 80
            };
            button.Click += (_, _) => dialog.Close();
            panel.Children.Add(button);
            dialog.Content = panel;

            await dialog.ShowDialog(this);
        }

        private void ConnectMbcButton_Click(object? sender, RoutedEventArgs e)
        {
            string address = MbcAddressTextBox.Text?.Trim() ?? string.Empty;
            _controller.ConnectMbc(address);
            I2cOffsetComboBox.SelectedItem = _controller.Settings.I2CAddrOffset.ToString();
            UpdateUiState();
        }

        private void ConnectBoardsButton_Click(object? sender, RoutedEventArgs e)
        {
            int offset = int.TryParse(I2cOffsetComboBox.SelectedItem?.ToString(), out int parsedOffset)
                ? parsedOffset
                : 0;
            _controller.ConnectBoards(offset);
            UpdateUiState();
        }

        private void GetDcdcUuidButton_Click(object? sender, RoutedEventArgs e)
        {
            _controller.RefreshBoardMetadata();
            UpdateUiState();
        }

        private async void SetDcdcUuidButton_Click(object? sender, RoutedEventArgs e)
        {
            if (!_controller.TrySetDcdcUuid(DcdcUuidTextBox.Text ?? string.Empty, out string errorMessage))
            {
                await ShowMessageAsync("Error", errorMessage);
            }
            UpdateUiState();
        }

        private void GetMainUuidButton_Click(object? sender, RoutedEventArgs e)
        {
            _controller.RefreshBoardMetadata();
            UpdateUiState();
        }

        private async void SetMainUuidButton_Click(object? sender, RoutedEventArgs e)
        {
            if (!_controller.TrySetMainBoardUuid(MainUuidTextBox.Text ?? string.Empty, out string errorMessage))
            {
                await ShowMessageAsync("Error", errorMessage);
            }
            UpdateUiState();
        }

        private async void CommunicationSettingsButton_Click(object? sender, RoutedEventArgs e)
        {
            await new CommunicationSettingsDialog().ShowDialog(this);
        }
        private void SwitchVdc1_Checked(object? sender, RoutedEventArgs e)
        {
            if (TryGetSwitchState(sender, out int state))
            {
                _controller.TrySwitchVdc(1, state);
                _controller.RefreshDcdcStatus();
                UpdateUiState();
            }
        }
        private void ClearFaultsVdc1Button_Click(object? sender, RoutedEventArgs e)
        {
            _controller.TryClearFaults(1);
            _controller.RefreshDcdcStatus();
            UpdateUiState();
        }

        private void StoreVdc1Button_Click(object? sender, RoutedEventArgs e)
        {
            _controller.TryStoreDefaults(1);
            UpdateUiState();
        }

        private void ApplyVdc1Button_Click(object? sender, RoutedEventArgs e)
        {
            ApplyDcdcChannel(1);
        }
        private void SwitchVdc2_Checked(object? sender, RoutedEventArgs e)
        {
            if (TryGetSwitchState(sender, out int state))
            {
                _controller.TrySwitchVdc(2, state);
                _controller.RefreshDcdcStatus();
                UpdateUiState();
            }
        }
        private void ClearFaultsVdc2Button_Click(object? sender, RoutedEventArgs e)
        {
            _controller.TryClearFaults(2);
            _controller.RefreshDcdcStatus();
            UpdateUiState();
        }

        private void StoreVdc2Button_Click(object? sender, RoutedEventArgs e)
        {
            _controller.TryStoreDefaults(2);
            UpdateUiState();
        }

        private void ApplyVdc2Button_Click(object? sender, RoutedEventArgs e)
        {
            ApplyDcdcChannel(2);
        }

        private void GetStatusButton_Click(object? sender, RoutedEventArgs e)
        {
            _controller.RefreshDcdcStatus();
            UpdateUiState();
        }

        private void SetTimerButton_Click(object? sender, RoutedEventArgs e)
        {
            _controller.TrySetTimer((ushort)Convert.ToInt32(SwitchOffTimerNumeric.Value));
            UpdateUiState();
        }

        private void GetTimerButton_Click(object? sender, RoutedEventArgs e)
        {
            SwitchOffTimerNumeric.Value = _controller.GetTimer();
            UpdateUiState();
        }

        private async void SetAttinyStatusButton_Click(object? sender, RoutedEventArgs e)
        {
            if (!byte.TryParse(AttinyStatusTextBox.Text, out byte value))
            {
                await ShowMessageAsync("Error", "ATtiny status must be a valid byte value between 0 and 255.");
                return;
            }

            _controller.TrySetAttinyStatus(value);
            AttinyStatusTextBox.Text = _controller.GetAttinyStatus().ToString();
            UpdateUiState();
        }

        private void GetAttinyStatusButton_Click(object? sender, RoutedEventArgs e)
        {
            AttinyStatusTextBox.Text = _controller.GetAttinyStatus().ToString();
            UpdateUiState();
        }
        private void DcdcStatusLed_Checked(object? sender, RoutedEventArgs e)
        {
            if (TryGetSwitchState(sender, out int state))
            {
                _controller.TrySwitchDcdcStatusLed(state);
                UpdateUiState();
            }
        }
        private void SetRgbLedButton_Click(object? sender, RoutedEventArgs e)
        {
            _controller.SetRgbLed(
                Convert.ToInt32(RgbLedIndexNumeric.Value),
                Convert.ToInt32(RedNumeric.Value),
                Convert.ToInt32(GreenNumeric.Value),
                Convert.ToInt32(BlueNumeric.Value),
                SwitchOffOthersCheckBox.IsChecked == true,
                ApplyImmediatelyCheckBox.IsChecked == true);
            UpdateUiState();
        }

        private void LightShowButton_Click(object? sender, RoutedEventArgs e)
        {
            _controller.RunLightShow();
            UpdateUiState();
        }
        private void MuxComboBox_SelectionChanged(object? sender, SelectionChangedEventArgs e)
        {
            if (MuxComboBox.SelectedItem is string selection)
            {
                _controller.SetMux(selection);
            }
        }

        private void SingleMeasurementButton_Click(object? sender, RoutedEventArgs e)
        {
            MeasurementSnapshot snapshot = _controller.MeasureSingle(MuxComboBox.SelectedItem?.ToString() ?? "Disable");
            AdcVoltageTextBox.Text = double.IsInfinity(snapshot.AdcVoltage) ? "n/a" : snapshot.AdcVoltage.ToString("F3");
            AdcResistanceTextBox.Text = double.IsInfinity(snapshot.AdcResistance) ? "n/a" : snapshot.AdcResistance.ToString("F3");
            UpdateUiState();
        }
        private async void MeasurementDialogButton_Click(object? sender, RoutedEventArgs e)
        {
            await new BurnInBoardMaintenanceMeasDialog().ShowDialog(this);
        }
        private void MainBoardStatusLedCheckBox_Changed(object? sender, RoutedEventArgs e)
        {
            _controller.TrySwitchMainBoardStatusLed(MainBoardStatusLedCheckBox.IsChecked == true);
            UpdateUiState();
        }

        private void GetTemperaturesButton_Click(object? sender, RoutedEventArgs e)
        {
            double[] temperatures = _controller.ReadTemperatures();
            T1TextBox.Text = double.IsNaN(temperatures[0]) ? "n/a" : temperatures[0].ToString("F3");
            T2TextBox.Text = double.IsNaN(temperatures[1]) ? "n/a" : temperatures[1].ToString("F3");
            T3TextBox.Text = double.IsNaN(temperatures[2]) ? "n/a" : temperatures[2].ToString("F3");
            UpdateUiState();
        }

        private async void SetFolderButton_Click(object? sender, RoutedEventArgs e)
        {
            if (TopLevel.GetTopLevel(this) is not TopLevel topLevel)
            {
                return;
            }

            var folders = await topLevel.StorageProvider.OpenFolderPickerAsync(new FolderPickerOpenOptions
            {
                AllowMultiple = false,
                Title = "Select measurement folder"
            });

            if (folders.Count > 0)
            {
                FolderTextBox.Text = folders[0].TryGetLocalPath() ?? FolderTextBox.Text;
            }
        }

        private void PeriodicMeasurementToggle_Changed(object? sender, RoutedEventArgs e)
        {
            if (PeriodicMeasurementToggle.IsChecked == true)
            {
                _measurementCountdownMinutes = Convert.ToDouble(MeasureEveryNumeric.Value);
                TimerMeasurementStatusTextBlock.Text = $"Next measurement in {_measurementCountdownMinutes:F1} min";
                _measurementTimer.Start();
            }
            else
            {
                _measurementTimer.Stop();
                TimerMeasurementStatusTextBlock.Text = "Periodic measurement is disabled.";
            }

            UpdateUiState();
        }

        private void SkipTimerButton_Click(object? sender, RoutedEventArgs e)
        {
            _measurementCountdownMinutes = 0;
            TimerMeasurementStatusTextBlock.Text = "Next measurement starts soon.";
            UpdateUiState();
        }
    }
}
