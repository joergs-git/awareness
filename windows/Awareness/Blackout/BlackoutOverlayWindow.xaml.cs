using System.Windows;
using System.Windows.Media.Animation;
using Awareness.Models;

namespace Awareness.Blackout;

/// <summary>
/// Full-screen overlay window for a single monitor during blackout.
/// Positioned to exactly cover one screen with transparency support for fade animations.
/// </summary>
public partial class BlackoutOverlayWindow : Window
{
    /// <summary>Fade animation duration in seconds (matches macOS 2-second fade)</summary>
    private static readonly Duration FadeDuration = new(TimeSpan.FromSeconds(2));

    public BlackoutOverlayWindow()
    {
        InitializeComponent();
    }

    /// <summary>
    /// Configure the content to display during this blackout.
    /// </summary>
    public void Configure(BlackoutVisualType visualType, string customText, string imagePath, string videoPath)
    {
        ContentControl.Configure(visualType, customText, imagePath, videoPath);
    }

    /// <summary>
    /// Replace the window content with a new UIElement (used for post-blackout phase swap).
    /// </summary>
    public void SetContent(UIElement content)
    {
        ContentControl.StopMedia();
        Content = content;
    }

    /// <summary>
    /// Restore the original BlackoutContentControl as the window content.
    /// </summary>
    public void RestoreContent()
    {
        Content = ContentControl;
    }

    /// <summary>
    /// Position this window to cover the specified screen bounds.
    /// Coordinates are in device-independent pixels (WPF logical units).
    /// </summary>
    public void PositionOnScreen(Rect screenBounds)
    {
        Left = screenBounds.Left;
        Top = screenBounds.Top;
        Width = screenBounds.Width;
        Height = screenBounds.Height;
    }

    /// <summary>
    /// Fade in the overlay with a 2-second ease-in animation.
    /// </summary>
    public void FadeIn(Action? completed = null)
    {
        var animation = new DoubleAnimation(0, 1, FadeDuration)
        {
            EasingFunction = new CubicEase { EasingMode = EasingMode.EaseIn }
        };

        if (completed != null)
            animation.Completed += (_, _) => completed();

        BeginAnimation(OpacityProperty, animation);
    }

    /// <summary>
    /// Fade out the overlay with a 2-second ease-out animation, then close.
    /// </summary>
    public void FadeOut(Action? completed = null)
    {
        ContentControl.StopMedia();

        var animation = new DoubleAnimation(1, 0, FadeDuration)
        {
            EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut }
        };

        animation.Completed += (_, _) =>
        {
            Close();
            completed?.Invoke();
        };

        BeginAnimation(OpacityProperty, animation);
    }
}
