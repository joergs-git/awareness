using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Imaging;
using Awareness.Models;
using Awareness.Resources;

namespace Awareness.Blackout;

/// <summary>
/// Displays different content based on the configured visual type during blackout.
/// Mirrors the macOS BlackoutContentView with identical behavior.
/// Text and image modes include a gentle breathing animation (scale + opacity pulsation).
/// </summary>
public partial class BlackoutContentControl : UserControl
{
    /// Storyboard for the breathing animation, kept as a field so it can be stopped on dismiss
    private Storyboard? _breathingStoryboard;

    public BlackoutContentControl()
    {
        InitializeComponent();
        VideoContent.MediaEnded += OnVideoMediaEnded;
    }

    /// <summary>
    /// Configure the content to display based on the visual type and parameters.
    /// </summary>
    public void Configure(BlackoutVisualType visualType, string customText, string imagePath, string videoPath)
    {
        // Hide everything first
        BreathingCircle.Visibility = Visibility.Collapsed;
        TextContent.Visibility = Visibility.Collapsed;
        ImageContent.Visibility = Visibility.Collapsed;
        VideoContent.Visibility = Visibility.Collapsed;
        VideoFallback.Visibility = Visibility.Collapsed;

        switch (visualType)
        {
            case BlackoutVisualType.PlainBlack:
                // Subtle breathing circle as minimal visual anchor
                BreathingCircle.Visibility = Visibility.Visible;
                StartBreathingAnimation(BreathingCircle, CircleScale, 0.015, 0.08);
                break;

            case BlackoutVisualType.Text:
                TextContent.Text = string.IsNullOrEmpty(customText) ? Strings.Breathe : customText;
                TextContent.Visibility = Visibility.Visible;
                StartBreathingAnimation(TextContent, TextScale, 0.25, 0.8);
                break;

            case BlackoutVisualType.Image:
                ConfigureImage(imagePath);
                break;

            case BlackoutVisualType.Video:
                ConfigureVideo(videoPath);
                break;
        }
    }

    /// <summary>
    /// Stop any active media playback and animations (called when the overlay is dismissed).
    /// </summary>
    public void StopMedia()
    {
        _breathingStoryboard?.Stop();
        _breathingStoryboard = null;
        VideoContent.Stop();
        VideoContent.Close();
    }

    private void ConfigureImage(string imagePath)
    {
        BitmapImage? bitmap = null;

        // Try user-selected custom image
        if (!string.IsNullOrEmpty(imagePath) && File.Exists(imagePath))
        {
            try
            {
                bitmap = new BitmapImage();
                bitmap.BeginInit();
                bitmap.UriSource = new Uri(imagePath, UriKind.Absolute);
                bitmap.CacheOption = BitmapCacheOption.OnLoad;
                bitmap.EndInit();
            }
            catch
            {
                bitmap = null;
            }
        }

        // Fall back to bundled default image
        if (bitmap == null)
        {
            try
            {
                bitmap = new BitmapImage(new Uri("pack://application:,,,/Resources/default-blackout.png", UriKind.Absolute));
            }
            catch
            {
                // Last resort: show text instead
                TextContent.Text = Strings.Breathe;
                TextContent.Foreground = new System.Windows.Media.SolidColorBrush(
                    System.Windows.Media.Color.FromArgb(128, 255, 255, 255));
                TextContent.Visibility = Visibility.Visible;
                return;
            }
        }

        ImageContent.Source = bitmap;
        ImageContent.Visibility = Visibility.Visible;
        StartBreathingAnimation(ImageContent, ImageScale, 0.6, 1.0);
    }

    private void ConfigureVideo(string videoPath)
    {
        if (!string.IsNullOrEmpty(videoPath) && File.Exists(videoPath))
        {
            VideoContent.Source = new Uri(videoPath, UriKind.Absolute);
            VideoContent.Visibility = Visibility.Visible;
            VideoContent.Play();
        }
        else
        {
            // No video configured — show fallback text
            VideoFallback.Visibility = Visibility.Visible;
        }
    }

    /// <summary>
    /// Loop the video by resetting position when it ends.
    /// </summary>
    private void OnVideoMediaEnded(object? sender, RoutedEventArgs e)
    {
        VideoContent.Position = TimeSpan.Zero;
        VideoContent.Play();
    }

    /// <summary>
    /// Start a gentle breathing animation on the given element: pulsating scale (0.95↔1.06)
    /// and opacity, matching the 3-second cycle used on macOS/iOS.
    /// Starts after a 2-second delay (fade-in time).
    /// </summary>
    private void StartBreathingAnimation(UIElement target, ScaleTransform scale, double opacityLow, double opacityHigh)
    {
        var duration = new Duration(TimeSpan.FromSeconds(3));

        // Scale X animation: 0.95 → 1.06
        var scaleXAnim = new DoubleAnimation(0.95, 1.06, duration)
        {
            AutoReverse = true,
            RepeatBehavior = RepeatBehavior.Forever,
            EasingFunction = new SineEase { EasingMode = EasingMode.EaseInOut }
        };
        Storyboard.SetTarget(scaleXAnim, target);
        Storyboard.SetTargetProperty(scaleXAnim,
            new PropertyPath("RenderTransform.ScaleX"));

        // Scale Y animation: 0.95 → 1.06
        var scaleYAnim = new DoubleAnimation(0.95, 1.06, duration)
        {
            AutoReverse = true,
            RepeatBehavior = RepeatBehavior.Forever,
            EasingFunction = new SineEase { EasingMode = EasingMode.EaseInOut }
        };
        Storyboard.SetTarget(scaleYAnim, target);
        Storyboard.SetTargetProperty(scaleYAnim,
            new PropertyPath("RenderTransform.ScaleY"));

        // Opacity animation
        var opacityAnim = new DoubleAnimation(opacityLow, opacityHigh, duration)
        {
            AutoReverse = true,
            RepeatBehavior = RepeatBehavior.Forever,
            EasingFunction = new SineEase { EasingMode = EasingMode.EaseInOut }
        };
        Storyboard.SetTarget(opacityAnim, target);
        Storyboard.SetTargetProperty(opacityAnim,
            new PropertyPath(UIElement.OpacityProperty));

        var storyboard = new Storyboard
        {
            // Start after the 2-second window fade-in
            BeginTime = TimeSpan.FromSeconds(2)
        };
        storyboard.Children.Add(scaleXAnim);
        storyboard.Children.Add(scaleYAnim);
        storyboard.Children.Add(opacityAnim);

        _breathingStoryboard = storyboard;
        storyboard.Begin(this, true);
    }
}
