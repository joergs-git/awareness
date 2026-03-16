using System.Globalization;

namespace Awareness.Models;

// Concrete, everyday situations where the user can practice that day's card principle.
// Not about changing behavior — about recognizing automatic patterns. Breaking the autopilot.
// Mirrors the macOS MicroTask struct.

public class MicroTask
{
    public string Id { get; }
    public string CardId { get; }   // Links to parent PracticeCard
    public string TextEN { get; }
    public string TextDE { get; }

    /// <summary>
    /// Returns the localized text based on the current UI culture.
    /// Falls back to English for any language other than German.
    /// </summary>
    public string LocalizedText =>
        CultureInfo.CurrentCulture.TwoLetterISOLanguageName == "de" ? TextDE : TextEN;

    public MicroTask(string id, string cardId, string textEN, string textDE)
    {
        Id = id;
        CardId = cardId;
        TextEN = textEN;
        TextDE = textDE;
    }

    // -------------------------------------------------------------------------
    // All micro-tasks grouped by card ID
    // -------------------------------------------------------------------------

    /// <summary>
    /// Complete pool of all micro-tasks across all cards.
    /// </summary>
    public static readonly MicroTask[] AllTasks =
    [
        .. LettingGoTasks,
        .. NonInterventionTasks,
        .. UndividedPerceptionTasks,
        .. UnhurriedResponseTasks,
        .. IntentionlessnessTasks,
        .. PresenceDailyLifeTasks,
        .. SilenceTasks,
    ];

    /// <summary>
    /// Returns all tasks associated with the given card ID.
    /// </summary>
    public static MicroTask[] TasksForCard(string cardId) =>
        [.. Array.FindAll(AllTasks, t => t.CardId == cardId)];

    // -------------------------------------------------------------------------
    // 1. Letting Go
    // -------------------------------------------------------------------------

    private static readonly MicroTask[] LettingGoTasks =
    [
        new("lg-01", "letting-go",
            "The next time you send a message, notice the urge to check for a reply. Don't check. Just notice the urge.",
            "Wenn du das nächste Mal eine Nachricht sendest, bemerke den Drang, auf Antwort zu prüfen. Prüfe nicht. Bemerke nur den Drang."),

        new("lg-02", "letting-go",
            "When you finish a task, observe whether your mind immediately grasps for the next one. Can you let the gap exist?",
            "Wenn du eine Aufgabe beendest, beobachte, ob dein Geist sofort nach der nächsten greift. Kannst du die Lücke bestehen lassen?"),

        new("lg-03", "letting-go",
            "The next thing that doesn't go as planned — watch your reaction. Who is it that expected something different?",
            "Beim nächsten Mal, wenn etwas nicht nach Plan läuft — beobachte deine Reaktion. Wer ist es, der etwas anderes erwartet hat?"),

        new("lg-04", "letting-go",
            "When cooking or eating, notice if you're already planning what comes after. Let the meal be enough.",
            "Beim Kochen oder Essen: Bemerkst du, dass du schon planst, was danach kommt? Lass die Mahlzeit genug sein."),

        new("lg-05", "letting-go",
            "The next time you tidy up, notice: are you cleaning, or are you trying to control?",
            "Wenn du das nächste Mal aufräumst, bemerke: Putzt du, oder versuchst du zu kontrollieren?"),

        new("lg-06", "letting-go",
            "When a conversation ends, notice if your mind replays it. Can you let it go as it was?",
            "Wenn ein Gespräch endet, bemerke, ob dein Geist es wiederholt. Kannst du es loslassen, wie es war?"),

        new("lg-07", "letting-go",
            "The next time you're waiting for someone, notice the pull toward impatience. Just notice it.",
            "Wenn du das nächste Mal auf jemanden wartest, bemerke den Zug zur Ungeduld. Bemerke ihn einfach."),

        new("lg-08", "letting-go",
            "When you close an app or finish reading, observe: what does the mind reach for next?",
            "Wenn du eine App schließt oder fertig liest, beobachte: Wonach greift der Geist als nächstes?"),
    ];

    // -------------------------------------------------------------------------
    // 2. Non-Intervention
    // -------------------------------------------------------------------------

    private static readonly MicroTask[] NonInterventionTasks =
    [
        new("ni-01", "non-intervention",
            "The next time someone does something 'wrong', watch your impulse to correct. Just observe it.",
            "Wenn jemand das nächste Mal etwas \u2018falsch\u2019 macht, beobachte deinen Impuls zu korrigieren. Beobachte ihn einfach."),

        new("ni-02", "non-intervention",
            "When you see something messy or out of place, notice the urge to fix it. Let it be.",
            "Wenn du etwas Unordentliches siehst, bemerke den Drang, es zu richten. Lass es so."),

        new("ni-03", "non-intervention",
            "The next conversation you have — listen without mentally editing what the other person should say.",
            "Im nächsten Gespräch — höre zu, ohne im Geist zu bearbeiten, was der andere sagen sollte."),

        new("ni-04", "non-intervention",
            "When a situation feels uncomfortable, watch yourself wanting to change it. What happens if you don't?",
            "Wenn sich eine Situation unbequem anfühlt, beobachte, wie du sie ändern willst. Was passiert, wenn du es nicht tust?"),

        new("ni-05", "non-intervention",
            "Notice a habit today — biting nails, fidgeting, checking phone. Don't stop it. Just see it.",
            "Bemerke heute eine Gewohnheit — Nägelkauen, Zappeln, Handy checken. Stoppe sie nicht. Sieh sie einfach."),

        new("ni-06", "non-intervention",
            "When someone tells you about a problem, notice the urge to offer solutions. Can you just listen?",
            "Wenn dir jemand von einem Problem erzählt, bemerke den Drang, Lösungen anzubieten. Kannst du einfach zuhören?"),

        new("ni-07", "non-intervention",
            "The next time something annoys you, don't react. Just watch the annoyance. Where is it in the body?",
            "Wenn dich das nächste Mal etwas nervt, reagiere nicht. Beobachte nur die Verärgerung. Wo ist sie im Körper?"),

        new("ni-08", "non-intervention",
            "When plans change unexpectedly, watch the resistance. You don't have to overcome it — just see it.",
            "Wenn sich Pläne unerwartet ändern, beobachte den Widerstand. Du musst ihn nicht überwinden — sieh ihn einfach."),
    ];

    // -------------------------------------------------------------------------
    // 3. Undivided Perception
    // -------------------------------------------------------------------------

    private static readonly MicroTask[] UndividedPerceptionTasks =
    [
        new("up-01", "undivided-perception",
            "When you make tea or coffee, do it with 100% awareness. Watch your hands, the cup, the water. Nothing else.",
            "Wenn du Tee oder Kaffee machst, tu es mit 100% Aufmerksamkeit. Beobachte deine Hände, die Tasse, das Wasser. Nichts anderes."),

        new("up-02", "undivided-perception",
            "The next time you eat, taste only. No screen, no reading, no planning. Just the food.",
            "Wenn du das nächste Mal isst, schmecke nur. Kein Bildschirm, kein Lesen, kein Planen. Nur das Essen."),

        new("up-03", "undivided-perception",
            "Walk to the next room and let your eyes rest on one thing for 30 seconds. See it completely.",
            "Geh in den nächsten Raum und lass deinen Blick 30 Sekunden auf einem Ding ruhen. Sieh es vollständig."),

        new("up-04", "undivided-perception",
            "The next time you wash your hands, feel only the water. The temperature, the pressure, the sound.",
            "Wenn du dir das nächste Mal die Hände wäschst, fühle nur das Wasser. Die Temperatur, den Druck, das Geräusch."),

        new("up-05", "undivided-perception",
            "Listen to the next sound you hear — fully. Not naming it, not judging it. Just hearing.",
            "Höre das nächste Geräusch, das du hörst — vollständig. Nicht benennen, nicht bewerten. Nur hören."),

        new("up-06", "undivided-perception",
            "The next time you look at a person, really look. Their face, their expression. Without narrating.",
            "Wenn du das nächste Mal eine Person anschaust, schau wirklich hin. Ihr Gesicht, ihr Ausdruck. Ohne zu kommentieren."),

        new("up-07", "undivided-perception",
            "Pick up the next object you touch with full attention. Feel its weight, texture, temperature.",
            "Nimm den nächsten Gegenstand, den du anfasst, mit voller Aufmerksamkeit auf. Fühle Gewicht, Textur, Temperatur."),

        new("up-08", "undivided-perception",
            "The next glass of water you drink — feel only this: lips, liquid, swallowing, coolness.",
            "Das nächste Glas Wasser, das du trinkst — fühle nur dies: Lippen, Flüssigkeit, Schlucken, Kühle."),
    ];

    // -------------------------------------------------------------------------
    // 4. Unhurried Response
    // -------------------------------------------------------------------------

    private static readonly MicroTask[] UnhurriedResponseTasks =
    [
        new("ur-01", "unhurried-response",
            "The next time someone asks you a question, notice the gap between hearing it and wanting to answer. Who wants to answer?",
            "Wenn dir das nächste Mal jemand eine Frage stellt, bemerke die Lücke zwischen Hören und Antworten-Wollen. Wer will antworten?"),

        new("ur-02", "unhurried-response",
            "Before you type your next message, pause. Feel the impulse to respond. Then respond — or don't.",
            "Bevor du deine nächste Nachricht tippst, halte inne. Fühle den Impuls zu antworten. Dann antworte — oder nicht."),

        new("ur-03", "unhurried-response",
            "The next time you feel criticized, watch the reflex to defend. There's a space before the reaction. Find it.",
            "Wenn du dich das nächste Mal kritisiert fühlst, beobachte den Reflex, dich zu verteidigen. Vor der Reaktion liegt ein Raum. Finde ihn."),

        new("ur-04", "unhurried-response",
            "When your phone vibrates, notice the pull to check. Count to three. Then decide — consciously.",
            "Wenn dein Handy vibriert, bemerke den Zug, nachzuschauen. Zähle bis drei. Dann entscheide — bewusst."),

        new("ur-05", "unhurried-response",
            "In your next conversation, wait one full breath after the other person finishes before you speak.",
            "Im nächsten Gespräch: Warte einen vollen Atemzug, nachdem der andere fertig ist, bevor du sprichst."),

        new("ur-06", "unhurried-response",
            "The next time you feel the urge to share an opinion, pause. Is it the situation asking, or your ego?",
            "Wenn du den nächsten Drang spürst, eine Meinung zu teilen, halte inne. Fragt die Situation — oder dein Ego?"),

        new("ur-07", "unhurried-response",
            "When you're about to interrupt someone, catch yourself. Where did that impulse come from?",
            "Wenn du jemanden unterbrechen willst, ertappe dich. Woher kam dieser Impuls?"),

        new("ur-08", "unhurried-response",
            "The next decision you make today — even a small one — pause and notice what's choosing.",
            "Die nächste Entscheidung, die du heute triffst — auch eine kleine — halte inne und bemerke, was entscheidet."),
    ];

    // -------------------------------------------------------------------------
    // 5. Intentionlessness
    // -------------------------------------------------------------------------

    private static readonly MicroTask[] IntentionlessnessTasks =
    [
        new("il-01", "intentionlessness",
            "Go for a short walk with no destination. Not for exercise, not for fresh air. Just walk.",
            "Mach einen kurzen Spaziergang ohne Ziel. Nicht für Bewegung, nicht für frische Luft. Einfach gehen."),

        new("il-02", "intentionlessness",
            "Sit for 60 seconds doing absolutely nothing. No goal. Not meditating. Not relaxing. Just sitting.",
            "Sitze 60 Sekunden und tu absolut nichts. Kein Ziel. Nicht meditieren. Nicht entspannen. Einfach sitzen."),

        new("il-03", "intentionlessness",
            "The next thing you do — can you do it without wanting a result? Washing a cup just to wash it.",
            "Das Nächste, das du tust — kannst du es ohne Ergebniserwartung tun? Eine Tasse spülen, nur um sie zu spülen."),

        new("il-04", "intentionlessness",
            "Look out the window. Not to check the weather, not to see anything specific. Just look.",
            "Schau aus dem Fenster. Nicht um das Wetter zu prüfen, nicht um etwas Bestimmtes zu sehen. Einfach schauen."),

        new("il-05", "intentionlessness",
            "Breathe without trying to breathe well. Let the breath be whatever it is.",
            "Atme, ohne gut atmen zu wollen. Lass den Atem sein, was er ist."),

        new("il-06", "intentionlessness",
            "The next time you eat, don't eat to be full. Just eat. One bite at a time.",
            "Wenn du das nächste Mal isst, iss nicht um satt zu werden. Iss einfach. Ein Bissen nach dem anderen."),

        new("il-07", "intentionlessness",
            "Pick up something and put it down. Not because it needs moving. Just to feel the act.",
            "Nimm etwas hoch und leg es wieder hin. Nicht weil es bewegt werden muss. Nur um die Handlung zu fühlen."),

        new("il-08", "intentionlessness",
            "Stand somewhere and do nothing. Not waiting. Not resting. Just standing.",
            "Steh irgendwo und tu nichts. Nicht warten. Nicht ruhen. Einfach stehen."),
    ];

    // -------------------------------------------------------------------------
    // 6. Presence in Daily Life
    // -------------------------------------------------------------------------

    private static readonly MicroTask[] PresenceDailyLifeTasks =
    [
        new("pdl-01", "presence-daily-life",
            "When you open a door, feel the handle. The temperature, the texture, the turning motion.",
            "Wenn du eine Tür öffnest, fühle die Klinke. Die Temperatur, die Textur, die Drehbewegung."),

        new("pdl-02", "presence-daily-life",
            "The next time you go up or down stairs, feel each step. Heel, sole, toe, lift.",
            "Wenn du das nächste Mal Treppen steigst, fühle jeden Schritt. Ferse, Sohle, Zehen, Abheben."),

        new("pdl-03", "presence-daily-life",
            "When you put on or take off clothes, feel the fabric on your skin. The pulling, the sliding.",
            "Wenn du dich an- oder ausziehst, fühle den Stoff auf deiner Haut. Das Ziehen, das Gleiten."),

        new("pdl-04", "presence-daily-life",
            "During your next shower, feel the water hit your skin. Where is it warm? Where does it run?",
            "Bei deiner nächsten Dusche: Fühle das Wasser auf deiner Haut. Wo ist es warm? Wohin läuft es?"),

        new("pdl-05", "presence-daily-life",
            "The next time you sit down in a chair, feel the moment of contact. The weight settling.",
            "Wenn du dich das nächste Mal hinsetzt, fühle den Moment des Kontakts. Das Gewicht, das sich senkt."),

        new("pdl-06", "presence-daily-life",
            "When you pay for something — tap, card, cash — notice the moment of exchange. What happens inside?",
            "Wenn du etwas bezahlst — tippen, Karte, Bargeld — bemerke den Moment des Austauschs. Was passiert innen?"),

        new("pdl-07", "presence-daily-life",
            "The next time you cook, feel the knife, the board, the ingredients. Each texture, each sound.",
            "Wenn du das nächste Mal kochst, fühle das Messer, das Brett, die Zutaten. Jede Textur, jedes Geräusch."),

        new("pdl-08", "presence-daily-life",
            "When you brush your teeth, feel only that. The bristles, the paste, the motion.",
            "Beim Zähneputzen fühle nur das. Die Borsten, die Paste, die Bewegung."),

        new("pdl-09", "presence-daily-life",
            "The next time you lock or unlock a door, be completely there for those three seconds.",
            "Wenn du das nächste Mal eine Tür auf- oder abschließt, sei komplett da für diese drei Sekunden."),

        new("pdl-10", "presence-daily-life",
            "When you get into a car or onto a bus, notice the transition. Outside to inside. Moving to sitting.",
            "Wenn du ins Auto oder in den Bus steigst, bemerke den Übergang. Draußen nach drinnen. Gehen zu Sitzen."),
    ];

    // -------------------------------------------------------------------------
    // 7. Silence
    // -------------------------------------------------------------------------

    private static readonly MicroTask[] SilenceTasks =
    [
        new("si-01", "silence",
            "The next pause in a conversation — don't fill it. Let the silence be.",
            "Die nächste Pause in einem Gespräch — fülle sie nicht. Lass die Stille sein."),

        new("si-02", "silence",
            "For the next 5 minutes, don't speak unless spoken to. Not as a rule — as an experiment.",
            "Sprich die nächsten 5 Minuten nicht, es sei denn, du wirst angesprochen. Nicht als Regel — als Experiment."),

        new("si-03", "silence",
            "Turn off all sounds on your devices for 30 minutes. Notice what the silence feels like.",
            "Schalte alle Geräusche deiner Geräte für 30 Minuten aus. Bemerke, wie sich die Stille anfühlt."),

        new("si-04", "silence",
            "The next time you're alone, don't turn on music, podcast, or TV. Listen to the room.",
            "Wenn du das nächste Mal allein bist, schalte keine Musik, keinen Podcast, keinen Fernseher ein. Höre den Raum."),

        new("si-05", "silence",
            "In your next conversation, listen for the silence between the words.",
            "Im nächsten Gespräch: Höre auf die Stille zwischen den Worten."),

        new("si-06", "silence",
            "When you walk outside, stop narrating the world. Just hear it.",
            "Wenn du draußen gehst, hör auf, die Welt zu kommentieren. Höre sie einfach."),

        new("si-07", "silence",
            "Before you sleep tonight, lie in silence for 2 minutes. Not meditating. Just lying quietly.",
            "Bevor du heute schlafen gehst, liege 2 Minuten in Stille. Nicht meditieren. Einfach ruhig liegen."),

        new("si-08", "silence",
            "The next time you want to say something, ask: does this need to be said, or does the silence serve better?",
            "Wenn du das nächste Mal etwas sagen willst, frage: Muss das gesagt werden, oder dient die Stille besser?"),
    ];
}
