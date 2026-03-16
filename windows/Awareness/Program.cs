using System;
using System.Windows;

namespace Awareness;

/// <summary>
/// Custom entry point that wraps the WPF Application startup in a try-catch.
/// This catches XAML parsing errors and static initializer failures that occur
/// before App.OnStartup runs — which would otherwise cause a silent crash.
/// </summary>
public static class Program
{
    [STAThread]
    public static void Main()
    {
        try
        {
            var app = new App();
            app.InitializeComponent();
            app.Run();
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Fatal startup error:\n\n{ex}", "Atempause Error",
                MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }
}
