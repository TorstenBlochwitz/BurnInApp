using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Platform.Storage;
using BurnIn.Shared;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Threading.Tasks;

namespace BurnInApp
{
    public partial class BurnInSettingsDialog : Window
    {
        private BurnInSettings _settings;
        private BurnInSettings _originalSettings;
        private ObservableCollection<IPAddressRow> _ipAddresses;
        private bool _isProfileRunning = false;

        public BurnInSettingsDialog()
        {
            InitializeComponent();
            _settings = new BurnInSettings();
            _originalSettings = new BurnInSettings();
            _ipAddresses = new ObservableCollection<IPAddressRow>();
            InitializeIPAddressGrid();
        }

        public BurnInSettingsDialog(BurnInSettings settings, bool isProfileRunning = false)
        {
            InitializeComponent();
            _settings = settings;
            _isProfileRunning = isProfileRunning;

            // Create a copy for cancel operation
            _originalSettings = new BurnInSettings
            {
                DMM6500_ID = settings.DMM6500_ID,
                MBC_Port = settings.MBC_Port,
                I2CAddrOffset = settings.I2CAddrOffset,
                Folder = settings.Folder,
                Postfix = settings.Postfix,
                FileName = settings.FileName,
                FolderStatus = settings.FolderStatus,
                FolderBurnInProfiles = settings.FolderBurnInProfiles,
                NumberOfMeasurementsForMeanValues = settings.NumberOfMeasurementsForMeanValues,
                StoreSelfTestResult = settings.StoreSelfTestResult,
                StoreSelfTestResultPeriod = settings.StoreSelfTestResultPeriod,
                BrightnessPosLEDs = settings.BrightnessPosLEDs,
                BrightnessStatusLEDs = settings.BrightnessStatusLEDs,
                IPAddress = (string[])settings.IPAddress.Clone(),
                MBCmode = settings.MBCmode
            };

            _ipAddresses = new ObservableCollection<IPAddressRow>();
            InitializeIPAddressGrid();
            LoadSettingsToControls();
            UpdateVisibility();
        }

        private void InitializeIPAddressGrid()
        {
            for (int i = 1; i <= 8; i++)
            {
                _ipAddresses.Add(new IPAddressRow { Position = i, IPAddress = "" });
            }
            IPAddressDataGrid.ItemsSource = _ipAddresses;
        }

        private void LoadSettingsToControls()
        {
            SettingsFileTextBox.Text = _settings.FileName;
            FolderBurnInProfilesTextBox.Text = _settings.FolderBurnInProfiles;
            FolderMeasurementTextBox.Text = _settings.Folder;
            FolderStatusTextBox.Text = _settings.FolderStatus;

            StoreSelfTestResultCheckBox.IsChecked = _settings.StoreSelfTestResult;
            StoreSelfTestResultPeriodTextBox.Text = _settings.StoreSelfTestResultPeriod.ToString();

            NumberOfMeasurementsTextBox.Text = _settings.NumberOfMeasurementsForMeanValues.ToString();

            BrightnessPositionLEDsSlider.Value = _settings.BrightnessPosLEDs;
            BrightnessStatusLEDsSlider.Value = _settings.BrightnessStatusLEDs;

            // Communication settings
            if (_settings.MBCmode == MBCModeEnum.I2C)
            {
                USBRadioButton.IsChecked = true;
            }
            else
            {
                EthernetRadioButton.IsChecked = true;
            }

            // Load IP addresses
            for (int i = 0; i < Math.Min(_settings.IPAddress.Length, _ipAddresses.Count); i++)
            {
                _ipAddresses[i].IPAddress = _settings.IPAddress[i];
            }

            // Platform-specific settings
            if (OperatingSystem.IsWindows())
            {
                SettingsFileTextBox.IsReadOnly = false;
                SetSettingsFileButton.IsEnabled = true;
            }
            else
            {
                SettingsFileTextBox.IsReadOnly = true;
                SetSettingsFileButton.IsEnabled = false;
            }
        }

        private void UpdateVisibility()
        {
            // Enable/disable period based on checkbox
            StoreSelfTestResultPeriodTextBox.IsEnabled = StoreSelfTestResultCheckBox.IsChecked ?? false;

            // Handle profile running state
            if (_isProfileRunning)
            {
                ChangesMessageTextBlock.Text = "No changes are allowed, because at least one BurnIn profile is running!";
                ChangesMessageTextBlock.Foreground = Avalonia.Media.Brushes.Red;
                IPAddressLabel.IsVisible = false;
                IPAddressDataGrid.IsVisible = false;
                ConnectMBCPanel.IsEnabled = false;
            }
            else
            {
                ChangesMessageTextBlock.Text = "Changes will be applied after the next start of the BurnIn App!";
                ChangesMessageTextBlock.Foreground = Avalonia.Media.Brushes.Orange;

                // Show/hide IP address grid based on mode
                bool showIPTable = EthernetRadioButton.IsChecked ?? false;
                IPAddressLabel.IsVisible = showIPTable;
                IPAddressDataGrid.IsVisible = showIPTable;
                ConnectMBCPanel.IsEnabled = true;
            }
        }

        private async void SetFolderMeasurement_Click(object? sender, RoutedEventArgs e)
        {
            var folder = await ShowFolderPickerAsync(FolderMeasurementTextBox.Text ?? "");
            if (folder != null)
            {
                FolderMeasurementTextBox.Text = folder;
            }
        }

        private async void SetFolderStatus_Click(object? sender, RoutedEventArgs e)
        {
            var folder = await ShowFolderPickerAsync(FolderStatusTextBox.Text ?? "");
            if (folder != null)
            {
                FolderStatusTextBox.Text = folder;
            }
        }

        private async void SetFolderBurnInProfiles_Click(object? sender, RoutedEventArgs e)
        {
            var folder = await ShowFolderPickerAsync(FolderBurnInProfilesTextBox.Text ?? "");
            if (folder != null)
            {
                FolderBurnInProfilesTextBox.Text = folder;
            }
        }

        private async void SetSettingsFile_Click(object? sender, RoutedEventArgs e)
        {
            var file = await ShowFileSavePickerAsync(SettingsFileTextBox.Text ?? "");
            if (file != null)
            {
                SettingsFileTextBox.Text = file;
            }
        }

        private void StoreSelfTestResult_Changed(object? sender, RoutedEventArgs e)
        {
            UpdateVisibility();
        }

        private void MBCMode_Changed(object? sender, RoutedEventArgs e)
        {
            UpdateVisibility();
        }

        private async void OK_Click(object? sender, RoutedEventArgs e)
        {
            // Validate IP addresses if Ethernet mode is selected
            if (EthernetRadioButton.IsChecked ?? false)
            {
                var uniqueIPs = new HashSet<string>();
                var duplicates = new List<int>();

                for (int i = 0; i < _ipAddresses.Count; i++)
                {
                    var ip = _ipAddresses[i].IPAddress ?? "";
                    if (!string.IsNullOrEmpty(ip))
                    {
                        if (!uniqueIPs.Add(ip))
                        {
                            duplicates.Add(i + 1);
                        }
                    }
                }

                if (duplicates.Count > 0)
                {
                    var msgBox = new Window
                    {
                        Title = "IP Addresses not unique",
                        Width = 400,
                        Height = 150,
                        WindowStartupLocation = WindowStartupLocation.CenterOwner,
                        CanResize = false,
                        Content = new StackPanel
                        {
                            Margin = new Avalonia.Thickness(20),
                            Spacing = 10,
                            Children =
                            {
                                new TextBlock
                                {
                                    Text = $"IP addresses are not unique!\n\nEnter unique IP addresses!",
                                    TextWrapping = Avalonia.Media.TextWrapping.Wrap
                                },
                                new Button
                                {
                                    Content = "OK",
                                    HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Center,
                                    Width = 80
                                }
                            }
                        }
                    };

                    ((Button)((StackPanel)msgBox.Content).Children[1]).Click += (s, args) => msgBox.Close();
                    await msgBox.ShowDialog(this);
                    return;
                }

                // Update IP addresses in settings
                for (int i = 0; i < Math.Min(_ipAddresses.Count, 8); i++)
                {
                    string newIP = _ipAddresses[i].IPAddress ?? "";
                    if (_settings.IPAddress[i] != newIP)
                    {
                        _settings.ComSettingsHaveChanged = true;
                    }
                    _settings.IPAddress[i] = newIP;
                }
            }

            // Update MBC mode
            if (USBRadioButton.IsChecked ?? false)
            {
                if (_settings.MBCmode != MBCModeEnum.I2C)
                {
                    _settings.ComSettingsHaveChanged = true;
                }
                _settings.MBCmode = MBCModeEnum.I2C;
            }
            else
            {
                if (_settings.MBCmode != MBCModeEnum.TCP)
                {
                    _settings.ComSettingsHaveChanged = true;
                }
                _settings.MBCmode = MBCModeEnum.TCP;
            }

            // Update all other settings
            _settings.Folder = FolderMeasurementTextBox.Text ?? "";
            _settings.FolderStatus = FolderStatusTextBox.Text ?? "";
            _settings.FolderBurnInProfiles = FolderBurnInProfilesTextBox.Text ?? "";
            _settings.FileName = SettingsFileTextBox.Text ?? "";
            _settings.StoreSelfTestResult = StoreSelfTestResultCheckBox.IsChecked ?? false;

            // Parse text box values with validation
            if (int.TryParse(StoreSelfTestResultPeriodTextBox.Text, out int period))
            {
                _settings.StoreSelfTestResultPeriod = period;
            }
            else
            {
                _settings.StoreSelfTestResultPeriod = 30; // default value
            }

            if (int.TryParse(NumberOfMeasurementsTextBox.Text, out int measurements))
            {
                _settings.NumberOfMeasurementsForMeanValues = measurements;
            }
            else
            {
                _settings.NumberOfMeasurementsForMeanValues = 5; // default value
            }

            _settings.BrightnessStatusLEDs = (int)(BrightnessStatusLEDsSlider.Value);
            _settings.BrightnessPosLEDs = (int)(BrightnessPositionLEDsSlider.Value);

            // Try to save settings to file
            if (!_settings.SaveToFile(_settings.FileName))
            {
                var msgBox = new Window
                {
                    Title = "Error",
                    Width = 400,
                    Height = 180,
                    WindowStartupLocation = WindowStartupLocation.CenterOwner,
                    CanResize = false,
                    Content = new StackPanel
                    {
                        Margin = new Avalonia.Thickness(20),
                        Spacing = 10,
                        Children =
                        {
                            new TextBlock
                            {
                                Text = $"Settings could not be stored in file: {_settings.FileName}\n\nPlease select a valid filename and a folder you have write access!",
                                TextWrapping = Avalonia.Media.TextWrapping.Wrap
                            },
                            new Button
                            {
                                Content = "OK",
                                HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Center,
                                Width = 80
                            }
                        }
                    }
                };

                ((Button)((StackPanel)msgBox.Content).Children[1]).Click += (s, args) => msgBox.Close();
                await msgBox.ShowDialog(this);
                SettingsFileTextBox.Focus();
                return;
            }

            Close(true);
        }

        private void Cancel_Click(object? sender, RoutedEventArgs e)
        {
            // Restore original settings
            _settings.DMM6500_ID = _originalSettings.DMM6500_ID;
            _settings.MBC_Port = _originalSettings.MBC_Port;
            _settings.I2CAddrOffset = _originalSettings.I2CAddrOffset;
            _settings.Folder = _originalSettings.Folder;
            _settings.Postfix = _originalSettings.Postfix;
            _settings.FileName = _originalSettings.FileName;
            _settings.FolderStatus = _originalSettings.FolderStatus;
            _settings.FolderBurnInProfiles = _originalSettings.FolderBurnInProfiles;
            _settings.NumberOfMeasurementsForMeanValues = _originalSettings.NumberOfMeasurementsForMeanValues;
            _settings.StoreSelfTestResult = _originalSettings.StoreSelfTestResult;
            _settings.StoreSelfTestResultPeriod = _originalSettings.StoreSelfTestResultPeriod;
            _settings.BrightnessPosLEDs = _originalSettings.BrightnessPosLEDs;
            _settings.BrightnessStatusLEDs = _originalSettings.BrightnessStatusLEDs;
            _settings.IPAddress = (string[])_originalSettings.IPAddress.Clone();
            _settings.MBCmode = _originalSettings.MBCmode;

            Close(false);
        }

        private async Task<string?> ShowFolderPickerAsync(string initialFolder)
        {
            var topLevel = TopLevel.GetTopLevel(this);
            if (topLevel == null) return null;

            var folders = await topLevel.StorageProvider.OpenFolderPickerAsync(new FolderPickerOpenOptions
            {
                Title = "Select Folder",
                AllowMultiple = false
            });

            if (folders.Count > 0)
            {
                return folders[0].Path.LocalPath;
            }

            return null;
        }

        private async Task<string?> ShowFileSavePickerAsync(string initialFile)
        {
            var topLevel = TopLevel.GetTopLevel(this);
            if (topLevel == null) return null;

            var file = await topLevel.StorageProvider.SaveFilePickerAsync(new FilePickerSaveOptions
            {
                Title = "Save Settings File",
                SuggestedFileName = string.IsNullOrEmpty(initialFile) ? "settings.json" : System.IO.Path.GetFileName(initialFile),
                DefaultExtension = "json",
                FileTypeChoices = new[]
                {
                    new FilePickerFileType("JSON Files") { Patterns = new[] { "*.json" } },
                    new FilePickerFileType("All Files") { Patterns = new[] { "*.*" } }
                }
            });

            if (file != null)
            {
                return file.Path.LocalPath;
            }

            return null;
        }
    }

    public class IPAddressRow
    {
        public int Position { get; set; }
        public string IPAddress { get; set; } = "";
    }
}
