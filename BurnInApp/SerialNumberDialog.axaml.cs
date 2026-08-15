using Avalonia.Controls;
using Avalonia.Interactivity;
using System;

namespace BurnInApp
{
    /// <summary>
    /// Dialog for editing serial number and number of emitters for a board.
    /// Converted from MATLAB SerialNumberDlg.mlapp by Torsten Blochwitz Electronics & Software for InfraSolid.
    /// </summary>
    public partial class SerialNumberDialog : Window
    {
        private BurnInController _controller;
        private int _boardIndex; // 1-based board index

        /// <summary>
        /// Result data containing the serial number and computed range for display updates
        /// </summary>
        public class DialogResult
        {
            public bool Confirmed { get; set; }
            public string SerialNumber { get; set; } = string.Empty;
            public int NumberOfEmitters { get; set; }
            public string SerialNumberRange { get; set; } = string.Empty;
        }

        public DialogResult Result { get; private set; } = new DialogResult();

        // Parameterless constructor required by Avalonia designer
        public SerialNumberDialog()
        {
            InitializeComponent();
            _controller = null!;
            _boardIndex = 1;
        }

        /// <summary>
        /// Initialize the dialog for a specific board
        /// </summary>
        /// <param name="controller">The BurnInController instance</param>
        /// <param name="boardIndex">1-based board index (1..8)</param>
        public SerialNumberDialog(BurnInController controller, int boardIndex) : this()
        {
            _controller = controller ?? throw new ArgumentNullException(nameof(controller));

            if (boardIndex < 1 || boardIndex > 8)
            {
                throw new ArgumentOutOfRangeException(nameof(boardIndex), "Board index must be between 1 and 8");
            }
            _boardIndex = boardIndex;

            Initialize();
        }

        private void Initialize()
        {
            int i = _boardIndex - 1;

            // Set current serial number
            SerialNumberTextBox.Text = _controller.SerialNumber[i];

            // Get maximum number of emitters from profile
            int maxEmitters = _controller.GetMaxNofEmitters(_boardIndex);

            // Update range label
            NumberRangeLabel.Content = $"1 ... {maxEmitters}";

            // Configure numeric input limits
            NumberNumericUpDown.Minimum = 1;
            NumberNumericUpDown.Maximum = maxEmitters;

            // Set current value, clamped to maximum
            int currentEmitters = _controller.NumberOfEmitters[i];
            NumberNumericUpDown.Value = Math.Min(currentEmitters, maxEmitters);

            // Focus on serial number field
            SerialNumberTextBox.Focus();
        }

        private async void OKButton_Click(object? sender, RoutedEventArgs e)
        {
            string serialNumberInput = SerialNumberTextBox.Text?.Trim().ToUpperInvariant() ?? string.Empty;

            if (!string.IsNullOrEmpty(serialNumberInput))
            {
                // Validate and normalize the serial number
                var (isValid, normalizedSNr) = SerialNumberHelper.GetSNr(serialNumberInput, 0);

                if (isValid)
                {
                    int i = _boardIndex - 1;
                    int numberOfEmitters = (int)(NumberNumericUpDown.Value ?? 1);

                    // Compute ending serial number for display
                    var (_, snrEnd) = SerialNumberHelper.GetSNr(normalizedSNr, numberOfEmitters);

                    // Update controller state
                    _controller.SerialNumber[i] = normalizedSNr;
                    _controller.NumberOfEmitters[i] = numberOfEmitters;

                    // Prepare result for caller
                    Result.Confirmed = true;
                    Result.SerialNumber = normalizedSNr;
                    Result.NumberOfEmitters = numberOfEmitters;
                    Result.SerialNumberRange = $"{normalizedSNr} - {snrEnd}";

                    Close(Result);
                }
                else
                {
                    // Show error without closing
                    var messageBox = new Window
                    {
                        Title = "Error in Serialnumber",
                        Width = 400,
                        Height = 150,
                        WindowStartupLocation = WindowStartupLocation.CenterOwner,
                        CanResize = false
                    };

                    var panel = new StackPanel
                    {
                        Margin = new Avalonia.Thickness(20),
                        Spacing = 20
                    };

                    panel.Children.Add(new TextBlock
                    {
                        Text = $"'{serialNumberInput}' is not a valid Serialnumber.\n\nEnter a valid Serialnumber for example 'AA0001'",
                        TextWrapping = Avalonia.Media.TextWrapping.Wrap
                    });

                    var okButton = new Button
                    {
                        Content = "OK",
                        HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Center,
                        MinWidth = 80
                    };
                    okButton.Click += (s, e) => messageBox.Close();
                    panel.Children.Add(okButton);

                    messageBox.Content = panel;
                    await messageBox.ShowDialog(this);
                }
            }
            else
            {
                // Empty serial number clears the value
                int i = _boardIndex - 1;
                _controller.SerialNumber[i] = string.Empty;

                Result.Confirmed = true;
                Result.SerialNumber = string.Empty;
                Result.NumberOfEmitters = _controller.NumberOfEmitters[i];
                Result.SerialNumberRange = string.Empty;

                Close(Result);
            }
        }

        private void CancelButton_Click(object? sender, RoutedEventArgs e)
        {
            // Leave controller state unchanged
            Result.Confirmed = false;
            Close(Result);
        }
    }
}
