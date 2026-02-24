using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media.Imaging;
using Awareness.Models;

namespace Awareness.Blackout;

/// <summary>
/// Displays different content based on the configured visual type during blackout.
/// Mirrors the macOS BlackoutContentView with identical behavior.
/// </summary>
public partial class BlackoutContentControl : UserControl
{
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
        TextContent.Visibility = Visibility.Collapsed;
        ImageContent.Visibility = Visibility.Collapsed;
        VideoContent.Visibility = Visibility.Collapsed;
        VideoFallback.Visibility = Visibility.Collapsed;

        switch (visualType)
        {
            case BlackoutVisualType.PlainBlack:
                // Just the black background — nothing to show
                break;

            case BlackoutVisualType.Text:
                TextContent.Text = string.IsNullOrEmpty(customText) ? "Breathe." : customText;
                TextContent.Visibility = Visibility.Visible;
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
    /// Stop any active media playback (called when the overlay is dismissed).
    /// </summary>
    public void StopMedia()
    {
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
                TextContent.Text = "Breathe.";
                TextContent.Foreground = new System.Windows.Media.SolidColorBrush(
                    System.Windows.Media.Color.FromArgb(128, 255, 255, 255));
                TextContent.Visibility = Visibility.Visible;
                return;
            }
        }

        ImageContent.Source = bitmap;
        ImageContent.Visibility = Visibility.Visible;
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
}
