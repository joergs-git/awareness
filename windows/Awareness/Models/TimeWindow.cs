namespace Awareness.Models;

/// <summary>
/// Represents the daily active time window during which blackouts may occur.
/// Hours are in 24-hour format (0-23).
/// Supports both normal ranges (e.g. 08:00-19:00) and overnight ranges (e.g. 22:00-06:00).
/// </summary>
public class TimeWindow
{
    public int StartHour { get; set; }
    public int EndHour { get; set; }

    public TimeWindow(int startHour, int endHour)
    {
        StartHour = startHour;
        EndHour = endHour;
    }

    /// <summary>
    /// Check whether the current time falls within this window.
    /// </summary>
    public bool IsCurrentlyActive()
    {
        int hour = DateTime.Now.Hour;

        if (StartHour <= EndHour)
        {
            // Normal range, e.g. 08:00-19:00
            return hour >= StartHour && hour < EndHour;
        }
        else
        {
            // Overnight range, e.g. 22:00-06:00
            return hour >= StartHour || hour < EndHour;
        }
    }
}
