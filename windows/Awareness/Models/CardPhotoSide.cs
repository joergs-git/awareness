namespace Awareness.Models;

/// <summary>Which face of a practice card a user-supplied photo represents.</summary>
public enum CardPhotoSide
{
    Front,
    Back
}

public static class CardPhotoSideExtensions
{
    /// <summary>Filename token used when storing the photo on disk.</summary>
    public static string FileToken(this CardPhotoSide side) =>
        side == CardPhotoSide.Front ? "front" : "back";
}
