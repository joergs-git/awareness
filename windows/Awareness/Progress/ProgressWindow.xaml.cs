using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Shapes;
using Awareness.Resources;
using Microsoft.Win32;

namespace Awareness.Progress;

/// <summary>
/// Progress statistics window showing twin donut charts (today + lifetime),
/// today/lifetime counters, a 14-day bar chart of triggered vs completed,
/// and an awareness response chart (yes/somewhat/no).
/// </summary>
public partial class ProgressWindow : Window
{
    // Warm earthy color matching the macOS/iOS donut charts: (0.72, 0.50, 0.38)
    private static readonly Color EarthyColor = Color.FromRgb(184, 128, 97); // #B88061
    private static readonly Brush EarthyBrush = new SolidColorBrush(EarthyColor);

    // Awareness response colors (matching macOS ProgressView)
    private static readonly Brush YesBrush = new SolidColorBrush(Color.FromRgb(0x73, 0x9A, 0x73));
    private static readonly Brush SomewhatBrush = new SolidColorBrush(Color.FromRgb(0x8C, 0x8E, 0xB3));
    private static readonly Brush NoBrush = new SolidColorBrush(Color.FromRgb(0xB3, 0x7F, 0x72));

    public ProgressWindow()
    {
        InitializeComponent();
        ApplyWarmBackground();
        Loaded += OnLoaded;
    }

    /// <summary>
    /// Detect Windows dark/light mode and set the warm gradient background accordingly.
    /// </summary>
    private void ApplyWarmBackground()
    {
        bool isDark = false;
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            if (key?.GetValue("AppsUseLightTheme") is int value)
                isDark = value == 0;
        }
        catch { /* Default to light */ }

        if (isDark)
        {
            TopGradientStop.Color = Color.FromRgb(36, 31, 28);    // (0.14, 0.12, 0.11)
            BottomGradientStop.Color = Color.FromRgb(26, 23, 20); // (0.10, 0.09, 0.08)
        }
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        var tracker = ProgressTracker.Shared;

        // Update stat labels
        TodayText.Text = $"{tracker.TodayCompleted} {Strings.Completed}, {tracker.TodayTriggered} {Strings.Triggered}";
        LifetimeText.Text = $"{tracker.LifetimeCompleted} {Strings.Completed}, {tracker.LifetimeTriggered} {Strings.Triggered}";

        DrawBrushDonut(TodayDonutCanvas, tracker.TodayRate, tracker.TodayTriggered > 0);
        DrawBrushDonut(LifetimeDonutCanvas, tracker.SuccessRate, tracker.LifetimeTriggered > 0);
        DrawBarChart(tracker);
        DrawAwarenessChart(tracker);
    }

    // MARK: - Brush-Stroke Donut

    /// <summary>
    /// Draw a donut chart with brush-stroke style overlay arcs.
    /// Multi-layer: primary arc + semi-transparent overlays at slight offsets for hand-drawn feel.
    /// </summary>
    private void DrawBrushDonut(Canvas canvas, double rate, bool hasData)
    {
        canvas.Children.Clear();

        double centerX = 60, centerY = 60;
        double radius = 48;
        double strokeWidth = 14;

        // Background ring
        DrawStrokeArc(canvas, centerX, centerY, radius, 0, 360, strokeWidth,
            new SolidColorBrush(Color.FromArgb(40, 128, 128, 128)), null);

        if (hasData && rate > 0)
        {
            double sweep = rate * 360;

            // Primary arc
            DrawStrokeArc(canvas, centerX, centerY, radius, -90, sweep, strokeWidth,
                EarthyBrush, null);

            // Brush-stroke overlays at slight pixel offsets
            DrawStrokeArc(canvas, centerX + 1, centerY - 0.8, radius, -90, sweep, 12,
                new SolidColorBrush(Color.FromArgb(128, EarthyColor.R, EarthyColor.G, EarthyColor.B)), null);
            DrawStrokeArc(canvas, centerX - 0.8, centerY + 1.2, radius, -90, sweep, 8.5,
                new SolidColorBrush(Color.FromArgb(77, EarthyColor.R, EarthyColor.G, EarthyColor.B)), null);
            DrawStrokeArc(canvas, centerX + 0.5, centerY + 0.8, radius, -90, sweep, 6,
                new SolidColorBrush(Color.FromArgb(51, EarthyColor.R, EarthyColor.G, EarthyColor.B)),
                new DoubleCollection { 10, 2 });
        }

        // Center text: percentage
        var percentText = new TextBlock
        {
            Text = hasData ? $"{(int)(rate * 100)}%" : "—",
            FontSize = 20,
            FontWeight = FontWeights.Bold,
            Foreground = Brushes.Black,
            TextAlignment = TextAlignment.Center
        };
        percentText.Measure(new Size(double.PositiveInfinity, double.PositiveInfinity));
        Canvas.SetLeft(percentText, centerX - percentText.DesiredSize.Width / 2);
        Canvas.SetTop(percentText, centerY - percentText.DesiredSize.Height / 2 - 4);
        canvas.Children.Add(percentText);

        // Sub-label
        var labelText = new TextBlock
        {
            Text = Strings.SuccessRate,
            FontSize = 8,
            Foreground = Brushes.Gray,
            TextAlignment = TextAlignment.Center
        };
        labelText.Measure(new Size(double.PositiveInfinity, double.PositiveInfinity));
        Canvas.SetLeft(labelText, centerX - labelText.DesiredSize.Width / 2);
        Canvas.SetTop(labelText, centerY + 8);
        canvas.Children.Add(labelText);
    }

    /// <summary>
    /// Draw a stroke-based arc (line with thickness, not filled ring).
    /// Uses round line caps for a softer look.
    /// </summary>
    private static void DrawStrokeArc(Canvas canvas, double cx, double cy, double radius,
        double startAngle, double sweepAngle, double strokeWidth, Brush stroke,
        DoubleCollection? dashArray)
    {
        if (sweepAngle <= 0) return;

        bool isFullCircle = sweepAngle >= 360;
        if (isFullCircle) sweepAngle = 359.99;

        double startRad = startAngle * Math.PI / 180;
        double endRad = (startAngle + sweepAngle) * Math.PI / 180;

        var startPoint = new Point(cx + radius * Math.Cos(startRad), cy + radius * Math.Sin(startRad));
        var endPoint = new Point(cx + radius * Math.Cos(endRad), cy + radius * Math.Sin(endRad));

        bool largeArc = sweepAngle > 180;

        var figure = new PathFigure { StartPoint = startPoint, IsClosed = false };
        figure.Segments.Add(new ArcSegment(endPoint, new Size(radius, radius), 0, largeArc,
            SweepDirection.Clockwise, true));

        var geometry = new PathGeometry();
        geometry.Figures.Add(figure);

        var path = new System.Windows.Shapes.Path
        {
            Data = geometry,
            Stroke = stroke,
            StrokeThickness = strokeWidth,
            StrokeStartLineCap = PenLineCap.Round,
            StrokeEndLineCap = PenLineCap.Round
        };

        if (dashArray != null)
            path.StrokeDashArray = dashArray;

        canvas.Children.Add(path);
    }

    /// <summary>
    /// Draw the 14-day bar chart showing triggered vs completed per day.
    /// </summary>
    private void DrawBarChart(ProgressTracker tracker)
    {
        BarChartCanvas.Children.Clear();

        var days = tracker.Last14Days;
        int maxVal = Math.Max(days.Max(d => Math.Max(d.Triggered, d.Completed)), 1);

        double canvasWidth = BarChartCanvas.ActualWidth > 0 ? BarChartCanvas.ActualWidth : 310;
        double chartHeight = 80;
        double barWidth = 7;
        double pairSpacing = 2;
        double pairWidth = barWidth * 2 + pairSpacing;
        double colSpacing = (canvasWidth - pairWidth * 14) / 13;
        if (colSpacing < 1) colSpacing = 1;

        var grayBrush = new SolidColorBrush(Color.FromArgb(100, 128, 128, 128));

        string todayKey = DateTime.Today.ToString("yyyy-MM-dd");

        for (int i = 0; i < days.Count; i++)
        {
            var day = days[i];
            double x = i * (pairWidth + colSpacing);

            // Triggered bar (gray)
            double triggeredHeight = day.Triggered > 0 ? Math.Max((double)day.Triggered / maxVal * chartHeight, 2) : 0;
            if (triggeredHeight > 0)
            {
                var rect = new Rectangle
                {
                    Width = barWidth,
                    Height = triggeredHeight,
                    Fill = grayBrush,
                    RadiusX = 1,
                    RadiusY = 1
                };
                Canvas.SetLeft(rect, x);
                Canvas.SetTop(rect, chartHeight - triggeredHeight);
                BarChartCanvas.Children.Add(rect);
            }

            // Completed bar (warm earthy)
            double completedHeight = day.Completed > 0 ? Math.Max((double)day.Completed / maxVal * chartHeight, 2) : 0;
            if (completedHeight > 0)
            {
                var rect = new Rectangle
                {
                    Width = barWidth,
                    Height = completedHeight,
                    Fill = EarthyBrush,
                    RadiusX = 1,
                    RadiusY = 1
                };
                Canvas.SetLeft(rect, x + barWidth + pairSpacing);
                Canvas.SetTop(rect, chartHeight - completedHeight);
                BarChartCanvas.Children.Add(rect);
            }

            // Weekday label
            var dateObj = DateTime.ParseExact(day.Date, "yyyy-MM-dd", CultureInfo.InvariantCulture);
            string weekday = dateObj.ToString("ddd").Substring(0, 1).ToUpper();

            var label = new TextBlock
            {
                Text = weekday,
                FontSize = 9,
                Foreground = day.Date == todayKey ? Brushes.Black : Brushes.Gray,
                TextAlignment = TextAlignment.Center,
                Width = pairWidth
            };
            Canvas.SetLeft(label, x);
            Canvas.SetTop(label, chartHeight + 4);
            BarChartCanvas.Children.Add(label);
        }
    }

    /// <summary>
    /// Draw the awareness response chart showing yes/somewhat/no per day for the last 14 days.
    /// Three bars per day in sage green, muted blue-violet, and dusty rose.
    /// </summary>
    private void DrawAwarenessChart(ProgressTracker tracker)
    {
        AwarenessChartCanvas.Children.Clear();

        var days = tracker.Last14Days;

        // Check if there's any awareness data at all
        bool hasData = days.Any(d => d.Yes > 0 || d.Somewhat > 0 || d.No > 0);
        if (!hasData) return;

        int maxVal = Math.Max(days.Max(d => Math.Max(d.Yes, Math.Max(d.Somewhat, d.No))), 1);

        double canvasWidth = AwarenessChartCanvas.ActualWidth > 0 ? AwarenessChartCanvas.ActualWidth : 310;
        double chartHeight = 60;
        double barWidth = 5;
        double tripleSpacing = 1;
        double tripleWidth = barWidth * 3 + tripleSpacing * 2;
        double colSpacing = (canvasWidth - tripleWidth * 14) / 13;
        if (colSpacing < 1) colSpacing = 1;

        string todayKey = DateTime.Today.ToString("yyyy-MM-dd");

        for (int i = 0; i < days.Count; i++)
        {
            var day = days[i];
            double x = i * (tripleWidth + colSpacing);

            DrawAwarenessBar(x, day.Yes, maxVal, chartHeight, barWidth, YesBrush);
            DrawAwarenessBar(x + barWidth + tripleSpacing, day.Somewhat, maxVal, chartHeight, barWidth, SomewhatBrush);
            DrawAwarenessBar(x + (barWidth + tripleSpacing) * 2, day.No, maxVal, chartHeight, barWidth, NoBrush);

            // Weekday label
            var dateObj = DateTime.ParseExact(day.Date, "yyyy-MM-dd", CultureInfo.InvariantCulture);
            string weekday = dateObj.ToString("ddd").Substring(0, 1).ToUpper();

            var label = new TextBlock
            {
                Text = weekday,
                FontSize = 8,
                Foreground = day.Date == todayKey ? Brushes.Black : Brushes.Gray,
                TextAlignment = TextAlignment.Center,
                Width = tripleWidth
            };
            Canvas.SetLeft(label, x);
            Canvas.SetTop(label, chartHeight + 4);
            AwarenessChartCanvas.Children.Add(label);
        }
    }

    private void DrawAwarenessBar(double x, int value, int maxVal, double chartHeight, double barWidth, Brush fill)
    {
        if (value <= 0) return;

        double height = Math.Max((double)value / maxVal * chartHeight, 2);
        var rect = new Rectangle
        {
            Width = barWidth,
            Height = height,
            Fill = fill,
            RadiusX = 1,
            RadiusY = 1
        };
        Canvas.SetLeft(rect, x);
        Canvas.SetTop(rect, chartHeight - height);
        AwarenessChartCanvas.Children.Add(rect);
    }
}
