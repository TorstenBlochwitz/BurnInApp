using Avalonia.Controls;
using Avalonia.Interactivity;

namespace BurnInBoardMaintenanceApp
{
    public partial class CommunicationSettingsDialog : Window
    {
        public CommunicationSettingsDialog()
        {
            InitializeComponent();
        }

        private void CloseButton_Click(object? sender, RoutedEventArgs e)
        {
            Close();
        }
    }
}
