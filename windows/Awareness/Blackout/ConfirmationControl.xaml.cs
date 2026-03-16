using System.Windows.Controls;

namespace Awareness.Blackout;

/// <summary>
/// Startclick confirmation overlay shown before a blackout begins.
/// Mirrors the macOS "Ready to breathe?" prompt (BlackoutContentView startclick state).
///
/// Usage: set OnConfirm / OnDecline callbacks, then show this control.
/// The parent (BlackoutWindowController) is responsible for showing/hiding it
/// and for any fade transitions.
/// </summary>
public partial class ConfirmationControl : UserControl
{
    /// <summary>
    /// Invoked when the user clicks "Yes" — proceed with the blackout.
    /// </summary>
    public Action? OnConfirm { get; set; }

    /// <summary>
    /// Invoked when the user clicks "No" — cancel this blackout occurrence.
    /// </summary>
    public Action? OnDecline { get; set; }

    public ConfirmationControl()
    {
        InitializeComponent();
    }

    private void OnYesClicked(object sender, System.Windows.RoutedEventArgs e)
    {
        OnConfirm?.Invoke();
    }

    private void OnNoClicked(object sender, System.Windows.RoutedEventArgs e)
    {
        OnDecline?.Invoke();
    }
}
