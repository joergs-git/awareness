using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;

namespace Awareness.Settings;

/// <summary>
/// A custom dual-thumb range slider control.
/// The low thumb cannot exceed the high thumb and vice versa.
/// Mirrors the macOS RangeSliderView from SwiftUI.
/// </summary>
public partial class RangeSlider : UserControl
{
    // MARK: - Dependency Properties

    public static readonly DependencyProperty MinimumProperty =
        DependencyProperty.Register(nameof(Minimum), typeof(double), typeof(RangeSlider),
            new PropertyMetadata(1.0, OnRangeChanged));

    public static readonly DependencyProperty MaximumProperty =
        DependencyProperty.Register(nameof(Maximum), typeof(double), typeof(RangeSlider),
            new PropertyMetadata(120.0, OnRangeChanged));

    public static readonly DependencyProperty LowValueProperty =
        DependencyProperty.Register(nameof(LowValue), typeof(double), typeof(RangeSlider),
            new FrameworkPropertyMetadata(15.0, FrameworkPropertyMetadataOptions.BindsTwoWayByDefault, OnValueChanged));

    public static readonly DependencyProperty HighValueProperty =
        DependencyProperty.Register(nameof(HighValue), typeof(double), typeof(RangeSlider),
            new FrameworkPropertyMetadata(30.0, FrameworkPropertyMetadataOptions.BindsTwoWayByDefault, OnValueChanged));

    public static readonly DependencyProperty StepProperty =
        DependencyProperty.Register(nameof(Step), typeof(double), typeof(RangeSlider),
            new PropertyMetadata(1.0));

    public double Minimum { get => (double)GetValue(MinimumProperty); set => SetValue(MinimumProperty, value); }
    public double Maximum { get => (double)GetValue(MaximumProperty); set => SetValue(MaximumProperty, value); }
    public double LowValue { get => (double)GetValue(LowValueProperty); set => SetValue(LowValueProperty, value); }
    public double HighValue { get => (double)GetValue(HighValueProperty); set => SetValue(HighValueProperty, value); }
    public double Step { get => (double)GetValue(StepProperty); set => SetValue(StepProperty, value); }

    // MARK: - State

    private enum DragTarget { None, Low, High }
    private DragTarget _dragging = DragTarget.None;

    public RangeSlider()
    {
        InitializeComponent();
    }

    // MARK: - Layout

    private static void OnRangeChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        ((RangeSlider)d).UpdateVisuals();
    }

    private static void OnValueChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        ((RangeSlider)d).UpdateVisuals();
    }

    private void OnCanvasSizeChanged(object sender, SizeChangedEventArgs e)
    {
        UpdateVisuals();
    }

    private void UpdateVisuals()
    {
        double totalWidth = SliderCanvas.ActualWidth;
        if (totalWidth <= 16) return;

        double range = Maximum - Minimum;
        if (range <= 0) return;

        double lowFrac = (LowValue - Minimum) / range;
        double highFrac = (HighValue - Minimum) / range;
        double usableWidth = totalWidth - 16; // thumb diameter

        // Track background spans full width
        TrackBackground.Width = totalWidth;

        // Highlight bar between the two thumbs
        double lowX = lowFrac * usableWidth + 8;  // center of low thumb
        double highX = highFrac * usableWidth + 8; // center of high thumb
        Canvas.SetLeft(TrackHighlight, lowX);
        TrackHighlight.Width = Math.Max(0, highX - lowX);

        // Position thumbs
        Canvas.SetLeft(LowThumb, lowFrac * usableWidth);
        Canvas.SetLeft(HighThumb, highFrac * usableWidth);
    }

    // MARK: - Mouse Interaction

    private void OnCanvasMouseDown(object sender, MouseButtonEventArgs e)
    {
        double x = e.GetPosition(SliderCanvas).X;
        double lowX = Canvas.GetLeft(LowThumb) + 8;
        double highX = Canvas.GetLeft(HighThumb) + 8;

        // Determine which thumb is closer to the click
        double distLow = Math.Abs(x - lowX);
        double distHigh = Math.Abs(x - highX);

        _dragging = distLow <= distHigh ? DragTarget.Low : DragTarget.High;
        SliderCanvas.CaptureMouse();
        UpdateValueFromPosition(x);
    }

    private void OnCanvasMouseMove(object sender, MouseEventArgs e)
    {
        if (_dragging == DragTarget.None) return;
        double x = e.GetPosition(SliderCanvas).X;
        UpdateValueFromPosition(x);
    }

    private void OnCanvasMouseUp(object sender, MouseButtonEventArgs e)
    {
        _dragging = DragTarget.None;
        SliderCanvas.ReleaseMouseCapture();
    }

    private void UpdateValueFromPosition(double x)
    {
        double totalWidth = SliderCanvas.ActualWidth;
        if (totalWidth <= 16) return;

        double usableWidth = totalWidth - 16;
        double fraction = Math.Clamp((x - 8) / usableWidth, 0, 1);
        double rawValue = Minimum + fraction * (Maximum - Minimum);
        double stepped = Math.Round(rawValue / Step) * Step;

        if (_dragging == DragTarget.Low)
        {
            LowValue = Math.Clamp(stepped, Minimum, HighValue);
        }
        else if (_dragging == DragTarget.High)
        {
            HighValue = Math.Clamp(stepped, LowValue, Maximum);
        }
    }
}
