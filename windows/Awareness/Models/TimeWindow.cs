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

    /// <summary>
    /// Check whether a specific DateTime falls within this window.
    /// </summary>
    public bool IsActive(DateTime dateTime)
    {
        int hour = dateTime.Hour;

        if (StartHour <= EndHour)
        {
            return hour >= StartHour && hour < EndHour;
        }
        else
        {
            return hour >= StartHour || hour < EndHour;
        }
    }

    /// <summary>
    /// The next time the active window starts, relative to now.
    /// Returns null if the window is currently active.
    /// </summary>
    public DateTime? NextWindowStart()
    {
        if (IsCurrentlyActive()) return null;

        var now = DateTime.Now;
        int hour = now.Hour;

        if (StartHour <= EndHour)
        {
            if (hour < StartHour)
            {
                return now.Date.AddHours(StartHour);
            }
            else
            {
                return now.Date.AddDays(1).AddHours(StartHour);
            }
        }
        else
        {
            if (hour < StartHour)
            {
                return now.Date.AddHours(StartHour);
            }
            else
            {
                return now.Date.AddDays(1).AddHours(StartHour);
            }
        }
    }
}
