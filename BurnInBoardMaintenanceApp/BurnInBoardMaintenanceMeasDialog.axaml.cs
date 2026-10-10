using Avalonia.Controls;
using Avalonia.Interactivity;

namespace BurnInBoardMaintenanceApp
{
    public partial class BurnInBoardMaintenanceMeasDialog : Window
    {
        public BurnInBoardMaintenanceMeasDialog()
        {
            InitializeComponent();
        }

        private void CloseButton_Click(object? sender, RoutedEventArgs e)
        {
            Close();
        }
    }
}
