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
/// and a candlestick awareness chart (min-max wick + median dot + trend line).
/// </summary>
public partial class ProgressWindow : Window
{
    // Warm earthy color matching the macOS/iOS donut charts: (0.72, 0.50, 0.38)
    private static readonly Color EarthyColor = Color.FromRgb(184, 128, 97); // #B88061
    private static readonly Brush EarthyBrush = new SolidColorBrush(EarthyColor);

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

            // Light text for dark background
            var lightBrush = new SolidColorBrush(Color.FromRgb(230, 225, 220));
            Foreground = lightBrush;
            var tbStyle = new Style(typeof(System.Windows.Controls.TextBlock));
            tbStyle.Setters.Add(new Setter(System.Windows.Controls.TextBlock.ForegroundProperty, lightBrush));
            Resources[typeof(System.Windows.Controls.TextBlock)] = tbStyle;
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
    /// Draw the awareness candlestick chart showing min-max wick, median dot,
    /// and trend line connecting medians across the last 14 days.
    /// </summary>
    private void DrawAwarenessChart(ProgressTracker tracker)
    {
        AwarenessChartCanvas.Children.Clear();

        var days = tracker.Last14Days;

        // Check if there's any awareness data at all
        bool hasData = days.Any(d => d.AwarenessScores.Count > 0);
        if (!hasData) return;

        double canvasWidth = AwarenessChartCanvas.ActualWidth > 0 ? AwarenessChartCanvas.ActualWidth : 310;
        double chartHeight = 60;
        double colWidth = canvasWidth / 14;

        string todayKey = DateTime.Today.ToString("yyyy-MM-dd");

        var grayBrush = new SolidColorBrush(Color.FromArgb(100, 128, 128, 128));

        // Collect median points for trend line
        var trendPoints = new List<Point>();

        for (int i = 0; i < days.Count; i++)
        {
            var day = days[i];
            double centerX = i * colWidth + colWidth / 2;

            if (day.AwarenessScores.Count > 0)
            {
                // Min-max wick (thin vertical line)
                double minY = chartHeight - (double)day.AwarenessMax / 100.0 * chartHeight;
                double maxY = chartHeight - (double)day.AwarenessMin / 100.0 * chartHeight;
                double wickHeight = Math.Max(maxY - minY, 1);

                var wick = new Rectangle
                {
                    Width = 1,
                    Height = wickHeight,
                    Fill = grayBrush
                };
                Canvas.SetLeft(wick, centerX - 0.5);
                Canvas.SetTop(wick, minY);
                AwarenessChartCanvas.Children.Add(wick);

                // Median dot
                double medianY = chartHeight - day.AwarenessMedian / 100.0 * chartHeight;
                var dot = new Ellipse
                {
                    Width = 5,
                    Height = 5,
                    Fill = EarthyBrush
                };
                Canvas.SetLeft(dot, centerX - 2.5);
                Canvas.SetTop(dot, medianY - 2.5);
                AwarenessChartCanvas.Children.Add(dot);

                trendPoints.Add(new Point(centerX, medianY));
            }

            // Weekday label
            var dateObj = DateTime.ParseExact(day.Date, "yyyy-MM-dd", CultureInfo.InvariantCulture);
            string weekday = dateObj.ToString("ddd").Substring(0, 1).ToUpper();

            var label = new TextBlock
            {
                Text = weekday,
                FontSize = 8,
                Foreground = day.Date == todayKey ? Brushes.Black : Brushes.Gray,
                TextAlignment = TextAlignment.Center,
                Width = colWidth
            };
            Canvas.SetLeft(label, i * colWidth);
            Canvas.SetTop(label, chartHeight + 4);
            AwarenessChartCanvas.Children.Add(label);
        }

        // Draw trend line connecting median dots
        if (trendPoints.Count >= 2)
        {
            var figure = new PathFigure { StartPoint = trendPoints[0], IsClosed = false };
            for (int i = 1; i < trendPoints.Count; i++)
            {
                figure.Segments.Add(new LineSegment(trendPoints[i], true));
            }
            var geometry = new PathGeometry();
            geometry.Figures.Add(figure);

            var trendLine = new System.Windows.Shapes.Path
            {
                Data = geometry,
                Stroke = EarthyBrush,
                StrokeThickness = 1
            };
            AwarenessChartCanvas.Children.Add(trendLine);
        }
    }
}
