using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Platform.Storage;
using Avalonia.Threading;
using BurnIn.Shared;
using System;
using System.Collections.ObjectModel;
using System.Globalization;
using System.Threading.Tasks;

namespace BurnInApp
{
    /// <summary>
    /// Read-only viewer for a BurnIn profile (steps, banks, measurement rate).
    /// Converted from MATLAB class by Torsten Blochwitz Electronics & Software for InfraSolid
    /// Note: this dialog is view-only; no data can be changed by the user.
    /// </summary>
    public partial class BurnInProfileViewerDlg : Window
    {
        private readonly BurnInController? _controller;
        private readonly int _boardIndex;
        private BurnInProfile _profile = null!;
        private int _nBanks;

        public BurnInProfileViewerDlg()
        {
            InitializeComponent();
        }

        public BurnInProfileViewerDlg(BurnInController controller, int boardIndex, int nBanks)
        {
            InitializeComponent();
            _controller = controller;
            _boardIndex = boardIndex;
            _profile = controller.BurnInProfiles[boardIndex - 1];
            _nBanks = nBanks;

            ProfileDataGrid.LoadingRow += ProfileDataGrid_LoadingRow;

            UpdateProfileTable();
        }

        private void UpdateProfileTable()
        {
            Bank2Panel.IsVisible = _nBanks >= 2;
            UpdateLoadButtonState();

            var rows = new ObservableCollection<ProfileStepRow>();
            for (int i = 0; i < _profile.Steps.Count; i++)
            {
                var step = _profile.Steps[i];
                var row = new ProfileStepRow
                {
                    StepNumber = i + 1,
                    Name = step.Name,
                    Duration = step.Duration.ToString(@"hh\:mm\:ss"),
                    PowerPerChannel1 = step.PowerPerChannel[0].ToString("F2", CultureInfo.InvariantCulture),
                    MaxCurrent1 = step.MaxCurrent[0].ToString("F2", CultureInfo.InvariantCulture),
                    MaxVoltage1 = step.MaxVoltage[0].ToString("F2", CultureInfo.InvariantCulture),
                    Frequency1 = step.Frequency[0].ToString("F2", CultureInfo.InvariantCulture),
                    DutyCycle1 = step.DutyCycle[0].ToString("F0", CultureInfo.InvariantCulture),
                    ComputeVDuT1 = step.ComputeVDuT[0].ToString(CultureInfo.InvariantCulture),
                    Measure = step.Measure.ToString("F0", CultureInfo.InvariantCulture)
                };

                if (_nBanks > 1)
                {
                    row.PowerPerChannel2 = step.PowerPerChannel[1].ToString("F2", CultureInfo.InvariantCulture);
                    row.MaxCurrent2 = step.MaxCurrent[1].ToString("F2", CultureInfo.InvariantCulture);
                    row.MaxVoltage2 = step.MaxVoltage[1].ToString("F2", CultureInfo.InvariantCulture);
                    row.Frequency2 = step.Frequency[1].ToString("F2", CultureInfo.InvariantCulture);
                    row.DutyCycle2 = step.DutyCycle[1].ToString("F0", CultureInfo.InvariantCulture);
                    row.ComputeVDuT2 = step.ComputeVDuT[1].ToString(CultureInfo.InvariantCulture);
                }
                else
                {
                    row.PowerPerChannel2 = "n/a";
                    row.MaxCurrent2 = "n/a";
                    row.MaxVoltage2 = "n/a";
                    row.Frequency2 = "n/a";
                    row.DutyCycle2 = "n/a";
                    row.ComputeVDuT2 = "n/a";
                }

                bool isCurrentStep = _profile.ProfileStatus == ProfileStatusEnum.RUNNING &&
                                      i == (_profile.CurrProfileStep > 0 ? _profile.CurrProfileStep - 1 : 0);
                row.IsCurrentStep = isCurrentStep;

                rows.Add(row);
            }

            ProfileDataGrid.ItemsSource = rows;

            FileNameTextBox.Text = _profile.IsProfileLoaded() ? _profile.CompleteFileName : string.Empty;

            Type1TextBox.Text = _profile.Type[0];
            Number1TextBox.Text = _profile.NumberOfChannels[0].ToString("F0", CultureInfo.InvariantCulture);
            Resistance1TextBox.Text = _profile.Resistance[0].ToString("F2", CultureInfo.InvariantCulture);
            Deviation1TextBox.Text = _profile.Deviation[0].ToString("F2", CultureInfo.InvariantCulture);

            if (_nBanks > 1)
            {
                Type2TextBox.Text = _profile.Type[1];
                Number2TextBox.Text = _profile.NumberOfChannels[1].ToString("F0", CultureInfo.InvariantCulture);
                Resistance2TextBox.Text = _profile.Resistance[1].ToString("F2", CultureInfo.InvariantCulture);
                Deviation2TextBox.Text = _profile.Deviation[1].ToString("F2", CultureInfo.InvariantCulture);
            }

            MeasurementRateTextBox.Text = _profile.MeasurementRate.ToString(@"hh\:mm\:ss");
        }

        private void UpdateLoadButtonState()
        {
            ProfileStatusEnum status = _profile.GetStatus();
            LoadProfileButton.IsEnabled = status == ProfileStatusEnum.EMPTY || status == ProfileStatusEnum.READY_TO_RUN;
        }

        private async void LoadProfile_Click(object? sender, RoutedEventArgs e)
        {
            if (_controller == null || _boardIndex < 1)
            {
                return;
            }

            var topLevel = TopLevel.GetTopLevel(this);
            if (topLevel == null)
            {
                return;
            }

            var files = await topLevel.StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions
            {
                Title = "Select a Profile Definition file",
                AllowMultiple = false,
                FileTypeFilter = new[]
                {
                    new FilePickerFileType("Excel workbook") { Patterns = new[] { "*.xlsx" } }
                }
            });

            if (files.Count == 0)
            {
                return;
            }

            var (success, status) = _profile.ReadFromExcelFile(files[0].Path.LocalPath);
            if (success)
            {
                _controller.SerialNumber[_boardIndex - 1] = string.Empty;
                _controller.NumberOfEmitters[_boardIndex - 1] = 120;
                _controller.SNrDisplayUpdateNeeded = true;
                UpdateProfileTable();
            }
            else
            {
                await ShowMessageAsync("Error", status);
            }
        }

        private void ProfileDataGrid_LoadingRow(object? sender, DataGridRowEventArgs e)
        {
            if (e.Row.DataContext is ProfileStepRow row && row.IsCurrentStep)
            {
                e.Row.Background = new Avalonia.Media.SolidColorBrush(Avalonia.Media.Color.FromRgb(255, 204, 0));
            }
            else
            {
                e.Row.Background = null;
            }
        }

        private void Close_Click(object? sender, RoutedEventArgs e)
        {
            Close();
        }

        private async Task ShowMessageAsync(string title, string message)
        {
            var dialog = new Window
            {
                Title = title,
                Width = 760,
                Height = 260,
                MinWidth = 520,
                MinHeight = 180,
                CanResize = false,
                WindowStartupLocation = WindowStartupLocation.CenterOwner
            };
            var closeButton = new Button
            {
                Content = "OK",
                IsDefault = true,
                MinWidth = 80,
                HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Center
            };
            closeButton.Click += (_, _) => dialog.Close();
            var messageTextBox = new TextBox
            {
                Text = message,
                IsReadOnly = true,
                AcceptsReturn = true,
                TextWrapping = Avalonia.Media.TextWrapping.Wrap,
                BorderThickness = new Avalonia.Thickness(0),
                Background = Avalonia.Media.Brushes.Transparent,
                IsTabStop = false
            };

            var messageScrollViewer = new ScrollViewer
            {
                Content = messageTextBox,
                VerticalScrollBarVisibility = Avalonia.Controls.Primitives.ScrollBarVisibility.Auto,
                HorizontalScrollBarVisibility = Avalonia.Controls.Primitives.ScrollBarVisibility.Disabled
            };

            var buttonPanel = new StackPanel
            {
                Orientation = Avalonia.Layout.Orientation.Horizontal,
                HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Center,
                Children = { closeButton }
            };
            Grid.SetRow(buttonPanel, 1);

            var contentGrid = new Grid
            {
                Margin = new Avalonia.Thickness(20),
                RowDefinitions = new RowDefinitions("*,Auto"),
                RowSpacing = 16,
                Children =
                {
                    messageScrollViewer,
                    buttonPanel
                }
            };
            dialog.Content = contentGrid;
            await dialog.ShowDialog(this);
        }
    }

    public class ProfileStepRow
    {
        public int StepNumber { get; set; }
        public string Name { get; set; } = "";
        public string Duration { get; set; } = "";
        public string PowerPerChannel1 { get; set; } = "";
        public string MaxCurrent1 { get; set; } = "";
        public string MaxVoltage1 { get; set; } = "";
        public string Frequency1 { get; set; } = "";
        public string DutyCycle1 { get; set; } = "";
        public string ComputeVDuT1 { get; set; } = "";
        public string PowerPerChannel2 { get; set; } = "";
        public string MaxCurrent2 { get; set; } = "";
        public string MaxVoltage2 { get; set; } = "";
        public string Frequency2 { get; set; } = "";
        public string DutyCycle2 { get; set; } = "";
        public string ComputeVDuT2 { get; set; } = "";
        public string Measure { get; set; } = "";
        public bool IsCurrentStep { get; set; }
    }
}
