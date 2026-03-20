using System.Globalization;
using System.Windows.Media;

namespace Awareness.Models;

// MARK: - Practice Card Model
// Seven daily mindfulness practice cards, each with a distinct contemplative theme
// and color. Cards are assigned randomly (avoiding yesterday's card) and optionally
// delivered as a morning notification.
// Mirrors the macOS PracticeCard.swift model.

public class PracticeCard
{
    /// <summary>Stable identifier, e.g. "letting-go"</summary>
    public string Id { get; init; }

    /// <summary>German full title, e.g. "Übung des Loslassens"</summary>
    public string TitleDE { get; init; }

    /// <summary>English full title, e.g. "Exercise of Letting Go"</summary>
    public string TitleEN { get; init; }

    /// <summary>German compact title for small surfaces, e.g. "Loslassen"</summary>
    public string ShortTitleDE { get; init; }

    /// <summary>English compact title for small surfaces, e.g. "Letting Go"</summary>
    public string ShortTitleEN { get; init; }

    /// <summary>German full philosophical description / practice instructions</summary>
    public string DescriptionDE { get; init; }

    /// <summary>English full philosophical description / practice instructions</summary>
    public string DescriptionEN { get; init; }

    /// <summary>German short assignment for notifications</summary>
    public string PromptDE { get; init; }

    /// <summary>English short assignment for notifications</summary>
    public string PromptEN { get; init; }

    /// <summary>Distinct card color</summary>
    public Color Color { get; init; }

    // -------------------------------------------------------------------------
    // Localization helpers — German when the UI culture is "de", English otherwise
    // -------------------------------------------------------------------------

    private static bool IsGerman =>
        CultureInfo.CurrentCulture.TwoLetterISOLanguageName == "de";

    /// <summary>Localized full title based on the current UI culture</summary>
    public string LocalizedTitle => IsGerman ? TitleDE : TitleEN;

    /// <summary>Localized short title for compact spaces</summary>
    public string LocalizedShortTitle => IsGerman ? ShortTitleDE : ShortTitleEN;

    /// <summary>Localized description based on the current UI culture</summary>
    public string LocalizedDescription => IsGerman ? DescriptionDE : DescriptionEN;

    /// <summary>Localized short prompt for notifications</summary>
    public string LocalizedPrompt => IsGerman ? PromptDE : PromptEN;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    public PracticeCard(
        string id,
        string titleDE, string titleEN,
        string shortTitleDE, string shortTitleEN,
        string descriptionDE, string descriptionEN,
        string promptDE, string promptEN,
        Color color)
    {
        Id = id;
        TitleDE = titleDE;
        TitleEN = titleEN;
        ShortTitleDE = shortTitleDE;
        ShortTitleEN = shortTitleEN;
        DescriptionDE = descriptionDE;
        DescriptionEN = descriptionEN;
        PromptDE = promptDE;
        PromptEN = promptEN;
        Color = color;
    }

    // -------------------------------------------------------------------------
    // The 7 Practice Cards
    // -------------------------------------------------------------------------

    /// <summary>All seven practice cards in canonical order</summary>
    public static readonly PracticeCard[] AllCards =
    [
        // 1. Letting Go — Warm amber (#C4956A)
        new PracticeCard(
            id: "letting-go",
            titleDE: "Übung des Loslassens",
            titleEN: "Exercise of Letting Go",
            shortTitleDE: "Loslassen",
            shortTitleEN: "Letting Go",
            descriptionDE:
                "Loslassen bedeutet nicht Gleichgültigkeit. Es bedeutet, die Dinge zu halten " +
                "wie Wasser in offenen Händen — präsent, aber ohne zu klammern. Heute übe, " +
                "das Ergebnis von Handlungen nicht festzuhalten. Beobachte den Impuls, " +
                "kontrollieren zu wollen, und lass ihn vorbeiziehen wie eine Wolke.",
            descriptionEN:
                "Letting go does not mean indifference. It means holding things like water " +
                "in open hands — present, but without grasping. Today, practice not clinging " +
                "to the outcome of your actions. Observe the impulse to control, and let it " +
                "pass like a cloud.",
            promptDE: "Beobachte heute den Impuls, Ergebnisse festzuhalten — und lass los.",
            promptEN: "Today, observe the impulse to hold on to outcomes — and let go.",
            color: Color.FromRgb(166, 107, 148) // soft plum
        ),

        // 2. Non-Intervention — Sage green (#7A9E7E)
        new PracticeCard(
            id: "non-intervention",
            titleDE: "Übung des Nicht-eingreifens",
            titleEN: "Exercise of Non-Intervention",
            shortTitleDE: "Nicht-eingreifen",
            shortTitleEN: "Non-Intervention",
            descriptionDE:
                "Nicht-eingreifen heißt nicht Untätigkeit. Es heißt, den Impuls zu bemerken, " +
                "etwas korrigieren oder reparieren zu wollen — und dann zu beobachten, was " +
                "passiert, wenn du es nicht tust. Die Welt dreht sich auch ohne dein Eingreifen. " +
                "Heute übe, Beobachter zu sein statt Korrektor.",
            descriptionEN:
                "Non-intervention does not mean inaction. It means noticing the impulse to " +
                "correct or fix — and then observing what happens when you don't. The world " +
                "keeps turning without your interference. Today, practice being the observer " +
                "rather than the corrector.",
            promptDE: "Beobachte heute den Impuls, korrigieren zu wollen — und greife nicht ein.",
            promptEN: "Today, notice the urge to correct — and don't intervene.",
            color: Color.FromRgb(122, 133, 173) // cool lavender
        ),

        // 3. Undivided Perception — Deep blue (#5B7BA5)
        new PracticeCard(
            id: "undivided-perception",
            titleDE: "Übung der ungeteilten Wahrnehmung",
            titleEN: "Exercise of Undivided Perception",
            shortTitleDE: "Ungeteilte Wahrnehmung",
            shortTitleEN: "Undivided Perception",
            descriptionDE:
                "Ungeteilte Wahrnehmung bedeutet, einer Sache die volle Aufmerksamkeit zu " +
                "schenken — ohne gleichzeitig zu planen, zu bewerten oder abzuschweifen. " +
                "Heute übe, bei einer alltäglichen Handlung vollständig anwesend zu sein. " +
                "Nicht Multitasking, sondern Uni-Tasking. Eine Sache. Ganz.",
            descriptionEN:
                "Undivided perception means giving one thing your full attention — without " +
                "simultaneously planning, judging, or wandering. Today, practice being " +
                "completely present during an ordinary activity. Not multitasking, but " +
                "uni-tasking. One thing. Completely.",
            promptDE: "Schenke heute einer alltäglichen Handlung deine volle, ungeteilte Aufmerksamkeit.",
            promptEN: "Today, give one ordinary activity your full, undivided attention.",
            color: Color.FromRgb(102, 97, 184) // deep indigo
        ),

        // 4. Unhurried Response — Dusty rose (#B07D8E)
        new PracticeCard(
            id: "unhurried-response",
            titleDE: "Übung der Antwort ohne Eile",
            titleEN: "Exercise of Unhurried Response",
            shortTitleDE: "Antwort ohne Eile",
            shortTitleEN: "Unhurried Response",
            descriptionDE:
                "Zwischen Reiz und Reaktion liegt ein Raum. In diesem Raum liegt unsere " +
                "Freiheit. Heute übe, diesen Raum zu finden — den Moment zwischen dem " +
                "Impuls zu antworten und der Antwort selbst. Nicht Langsamkeit, sondern " +
                "Bewusstheit.",
            descriptionEN:
                "Between stimulus and response there is a space. In that space lies our " +
                "freedom. Today, practice finding that space — the moment between the " +
                "impulse to respond and the response itself. Not slowness, but awareness.",
            promptDE: "Finde heute den Raum zwischen Impuls und Reaktion.",
            promptEN: "Today, find the space between impulse and response.",
            color: Color.FromRgb(158, 107, 158) // mauve
        ),

        // 5. Intentionlessness — Soft violet (#8E7EAA)
        new PracticeCard(
            id: "intentionlessness",
            titleDE: "Übung der Absichtslosigkeit",
            titleEN: "Exercise of Intentionlessness",
            shortTitleDE: "Absichtslosigkeit",
            shortTitleEN: "Intentionlessness",
            descriptionDE:
                "Absichtslosigkeit bedeutet, etwas zu tun, ohne ein Ziel damit zu verfolgen. " +
                "Nicht gehen, um irgendwo anzukommen. Nicht atmen, um sich zu beruhigen. " +
                "Einfach tun. Heute übe, eine Handlung von ihrem Zweck zu lösen. Tu etwas, " +
                "nur um es zu tun.",
            descriptionEN:
                "Intentionlessness means doing something without pursuing a goal. Not walking " +
                "to get somewhere. Not breathing to calm down. Just doing. Today, practice " +
                "separating an action from its purpose. Do something just to do it.",
            promptDE: "Tu heute etwas nur um des Tuns willen — ohne Ziel, ohne Zweck.",
            promptEN: "Today, do something just for the sake of doing it — no goal, no purpose.",
            color: Color.FromRgb(143, 115, 179) // soft violet
        ),

        // 6. Presence in Daily Life — Earthy terracotta (#B5735A)
        new PracticeCard(
            id: "presence-daily-life",
            titleDE: "Übung der Präsenz im Alltag",
            titleEN: "Exercise of Presence in Daily Life",
            shortTitleDE: "Präsenz im Alltag",
            shortTitleEN: "Daily Presence",
            descriptionDE:
                "Präsenz braucht keine besondere Umgebung. Jeder Moment ist ein Tor zur " +
                "Achtsamkeit — das Öffnen einer Tür, das Treppensteigen, das Anfassen " +
                "eines Gegenstands. Heute übe, in gewöhnlichen Momenten vollständig da " +
                "zu sein. Die Meditation ist nicht auf dem Kissen — sie ist überall.",
            descriptionEN:
                "Presence needs no special setting. Every moment is a gateway to awareness — " +
                "opening a door, climbing stairs, touching an object. Today, practice being " +
                "fully present in ordinary moments. The meditation is not on the cushion — " +
                "it is everywhere.",
            promptDE: "Sei heute in einem gewöhnlichen Moment vollständig anwesend.",
            promptEN: "Today, be fully present in one ordinary moment.",
            color: Color.FromRgb(148, 97, 140) // warm violet
        ),

        // 7. Silence — Muted slate (#6B7F8E)
        new PracticeCard(
            id: "silence",
            titleDE: "Übung der Stille",
            titleEN: "Exercise of Silence",
            shortTitleDE: "Stille",
            shortTitleEN: "Silence",
            descriptionDE:
                "Stille ist nicht die Abwesenheit von Geräuschen — sie ist die Anwesenheit " +
                "von Aufmerksamkeit. Heute übe, Stille zu finden: in Gesprächen, in Pausen, " +
                "in den Räumen zwischen den Worten. Nicht Schweigen als Disziplin, sondern " +
                "Stille als Entdeckung.",
            descriptionEN:
                "Silence is not the absence of sound — it is the presence of attention. " +
                "Today, practice finding silence: in conversations, in pauses, in the spaces " +
                "between words. Not silence as discipline, but silence as discovery.",
            promptDE: "Finde heute die Stille zwischen den Worten und in den Pausen.",
            promptEN: "Today, find the silence between words and in the pauses.",
            color: Color.FromRgb(122, 117, 158) // cool purple-gray
        )
    ];

    // -------------------------------------------------------------------------
    // Lookup
    // -------------------------------------------------------------------------

    /// <summary>Find a card by its ID, or null if not found</summary>
    public static PracticeCard? CardWithId(string id) =>
        Array.Find(AllCards, c => c.Id == id);
}
