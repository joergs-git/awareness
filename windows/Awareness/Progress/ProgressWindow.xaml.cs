using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Shapes;
using Awareness.Resources;
using Microsoft.Win32;

namespace Awareness.Progress;

/// <summary>
/// Progress statistics window showing a donut chart, today/lifetime counters,
/// and a 14-day bar chart of triggered vs completed blackouts.
/// </summary>
public partial class ProgressWindow : Window
{
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

        DrawDonutChart(tracker);
        DrawBarChart(tracker);
    }

    /// <summary>
    /// Draw the donut chart on the canvas showing completion rate.
    /// </summary>
    private void DrawDonutChart(ProgressTracker tracker)
    {
        DonutCanvas.Children.Clear();

        double centerX = 70, centerY = 70;
        double outerRadius = 60, innerRadius = 44;
        double rate = tracker.SuccessRate;
        bool hasData = tracker.LifetimeTriggered > 0;

        // Background ring (gray)
        DrawArc(DonutCanvas, centerX, centerY, outerRadius, innerRadius, 0, 360,
            new SolidColorBrush(Color.FromArgb(50, 128, 128, 128)));

        // Completed arc (green)
        if (hasData && rate > 0)
        {
            double sweepAngle = rate * 360;
            DrawArc(DonutCanvas, centerX, centerY, outerRadius, innerRadius, -90, sweepAngle,
                new SolidColorBrush(Color.FromRgb(0x4C, 0xAF, 0x50)));
        }

        // Center text: percentage
        var percentText = new TextBlock
        {
            Text = hasData ? $"{(int)(rate * 100)}%" : "—",
            FontSize = 22,
            FontWeight = FontWeights.Bold,
            Foreground = Brushes.Black,
            TextAlignment = TextAlignment.Center
        };
        percentText.Measure(new Size(double.PositiveInfinity, double.PositiveInfinity));
        Canvas.SetLeft(percentText, centerX - percentText.DesiredSize.Width / 2);
        Canvas.SetTop(percentText, centerY - percentText.DesiredSize.Height / 2 - 6);
        DonutCanvas.Children.Add(percentText);

        // Sub-label: "Discipline"
        var labelText = new TextBlock
        {
            Text = Strings.SuccessRate,
            FontSize = 9,
            Foreground = Brushes.Gray,
            TextAlignment = TextAlignment.Center
        };
        labelText.Measure(new Size(double.PositiveInfinity, double.PositiveInfinity));
        Canvas.SetLeft(labelText, centerX - labelText.DesiredSize.Width / 2);
        Canvas.SetTop(labelText, centerY + 8);
        DonutCanvas.Children.Add(labelText);
    }

    /// <summary>
    /// Draw an arc (ring segment) on a canvas using Path geometry.
    /// </summary>
    private static void DrawArc(Canvas canvas, double cx, double cy,
        double outerR, double innerR, double startAngle, double sweepAngle, Brush fill)
    {
        if (sweepAngle <= 0) return;

        // Clamp sweep to avoid full-circle rendering issues
        bool isFullCircle = sweepAngle >= 360;
        if (isFullCircle) sweepAngle = 359.99;

        double startRad = startAngle * Math.PI / 180;
        double endRad = (startAngle + sweepAngle) * Math.PI / 180;

        var outerStart = new Point(cx + outerR * Math.Cos(startRad), cy + outerR * Math.Sin(startRad));
        var outerEnd = new Point(cx + outerR * Math.Cos(endRad), cy + outerR * Math.Sin(endRad));
        var innerStart = new Point(cx + innerR * Math.Cos(endRad), cy + innerR * Math.Sin(endRad));
        var innerEnd = new Point(cx + innerR * Math.Cos(startRad), cy + innerR * Math.Sin(startRad));

        bool largeArc = sweepAngle > 180;

        var figure = new PathFigure { StartPoint = outerStart, IsClosed = true };
        figure.Segments.Add(new ArcSegment(outerEnd, new Size(outerR, outerR), 0, largeArc,
            SweepDirection.Clockwise, true));
        figure.Segments.Add(new LineSegment(innerStart, true));
        figure.Segments.Add(new ArcSegment(innerEnd, new Size(innerR, innerR), 0, largeArc,
            SweepDirection.Counterclockwise, true));

        var geometry = new PathGeometry();
        geometry.Figures.Add(figure);

        var path = new Path { Data = geometry, Fill = fill };
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

        double canvasWidth = BarChartCanvas.ActualWidth > 0 ? BarChartCanvas.ActualWidth : 290;
        double chartHeight = 80;
        double barWidth = 7;
        double pairSpacing = 2;
        double pairWidth = barWidth * 2 + pairSpacing;
        double colSpacing = (canvasWidth - pairWidth * 14) / 13;
        if (colSpacing < 1) colSpacing = 1;

        var grayBrush = new SolidColorBrush(Color.FromArgb(100, 128, 128, 128));
        var greenBrush = new SolidColorBrush(Color.FromRgb(0x4C, 0xAF, 0x50));

        string todayKey = DateTime.Today.ToString("yyyy-MM-dd");

        for (int i = 0; i < days.Count; i++)
        {
            var day = days[i];
            double x = i * (pairWidth + colSpacing);

            // Triggered bar
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

            // Completed bar
            double completedHeight = day.Completed > 0 ? Math.Max((double)day.Completed / maxVal * chartHeight, 2) : 0;
            if (completedHeight > 0)
            {
                var rect = new Rectangle
                {
                    Width = barWidth,
                    Height = completedHeight,
                    Fill = greenBrush,
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
}
