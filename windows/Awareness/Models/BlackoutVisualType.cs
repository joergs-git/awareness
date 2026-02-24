namespace Awareness.Models;

/// <summary>
/// Defines what the user sees during a blackout overlay.
/// Mirrors the macOS BlackoutVisualType enum.
/// </summary>
public enum BlackoutVisualType
{
    PlainBlack,
    Text,
    Image,
    Video
}

public static class BlackoutVisualTypeExtensions
{
    public static string DisplayName(this BlackoutVisualType type) => type switch
    {
        BlackoutVisualType.PlainBlack => "Plain Black",
        BlackoutVisualType.Text => "Custom Text",
        BlackoutVisualType.Image => "Image",
        BlackoutVisualType.Video => "Video",
        _ => type.ToString()
    };

    /// <summary>
    /// Converts to a stable string for JSON serialization.
    /// </summary>
    public static string ToSerializedString(this BlackoutVisualType type) => type switch
    {
        BlackoutVisualType.PlainBlack => "plainBlack",
        BlackoutVisualType.Text => "text",
        BlackoutVisualType.Image => "image",
        BlackoutVisualType.Video => "video",
        _ => "text"
    };

    /// <summary>
    /// Parses from the serialized string representation.
    /// </summary>
    public static BlackoutVisualType FromSerializedString(string value) => value switch
    {
        "plainBlack" => BlackoutVisualType.PlainBlack,
        "text" => BlackoutVisualType.Text,
        "image" => BlackoutVisualType.Image,
        "video" => BlackoutVisualType.Video,
        _ => BlackoutVisualType.Text
    };
}
