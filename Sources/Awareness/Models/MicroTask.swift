import Foundation

// MARK: - Micro-Task Model
// Concrete, everyday situations where the user can practice that day's card principle.
// Not about changing behavior — about recognizing automatic patterns. Breaking the autopilot.

struct MicroTask: Identifiable {
    let id: String
    let cardID: String       // Links to parent PracticeCard
    let textEN: String
    let textDE: String

    /// Localized text based on current locale
    var localizedText: String {
        Locale.current.language.languageCode?.identifier == "de" ? textDE : textEN
    }
}

// MARK: - Micro-Task Pools (per card, ~8-12 each)

extension MicroTask {

    /// All micro-tasks grouped by card ID
    static let allTasks: [MicroTask] = lettingGoTasks + nonInterventionTasks
        + undividedPerceptionTasks + unhurriedResponseTasks
        + intentionlessnessTasks + presenceDailyLifeTasks + silenceTasks

    /// Return tasks for a specific card
    static func tasks(forCardID cardID: String) -> [MicroTask] {
        allTasks.filter { $0.cardID == cardID }
    }

    // MARK: 1. Letting Go

    private static let lettingGoTasks: [MicroTask] = [
        MicroTask(
            id: "lg-01", cardID: "letting-go",
            textEN: "The next time you send a message, notice the urge to check for a reply. Don't check. Just notice the urge.",
            textDE: "Wenn du das nächste Mal eine Nachricht sendest, bemerke den Drang, auf Antwort zu prüfen. Prüfe nicht. Bemerke nur den Drang."
        ),
        MicroTask(
            id: "lg-02", cardID: "letting-go",
            textEN: "When you finish a task, observe whether your mind immediately grasps for the next one. Can you let the gap exist?",
            textDE: "Wenn du eine Aufgabe beendest, beobachte, ob dein Geist sofort nach der nächsten greift. Kannst du die Lücke bestehen lassen?"
        ),
        MicroTask(
            id: "lg-03", cardID: "letting-go",
            textEN: "The next thing that doesn't go as planned — watch your reaction. Who is it that expected something different?",
            textDE: "Beim nächsten Mal, wenn etwas nicht nach Plan läuft — beobachte deine Reaktion. Wer ist es, der etwas anderes erwartet hat?"
        ),
        MicroTask(
            id: "lg-04", cardID: "letting-go",
            textEN: "When cooking or eating, notice if you're already planning what comes after. Let the meal be enough.",
            textDE: "Beim Kochen oder Essen: Bemerkst du, dass du schon planst, was danach kommt? Lass die Mahlzeit genug sein."
        ),
        MicroTask(
            id: "lg-05", cardID: "letting-go",
            textEN: "The next time you tidy up, notice: are you cleaning, or are you trying to control?",
            textDE: "Wenn du das nächste Mal aufräumst, bemerke: Putzt du, oder versuchst du zu kontrollieren?"
        ),
        MicroTask(
            id: "lg-06", cardID: "letting-go",
            textEN: "When a conversation ends, notice if your mind replays it. Can you let it go as it was?",
            textDE: "Wenn ein Gespräch endet, bemerke, ob dein Geist es wiederholt. Kannst du es loslassen, wie es war?"
        ),
        MicroTask(
            id: "lg-07", cardID: "letting-go",
            textEN: "The next time you're waiting for someone, notice the pull toward impatience. Just notice it.",
            textDE: "Wenn du das nächste Mal auf jemanden wartest, bemerke den Zug zur Ungeduld. Bemerke ihn einfach."
        ),
        MicroTask(
            id: "lg-08", cardID: "letting-go",
            textEN: "When you close an app or finish reading, observe: what does the mind reach for next?",
            textDE: "Wenn du eine App schließt oder fertig liest, beobachte: Wonach greift der Geist als nächstes?"
        ),
    ]

    // MARK: 2. Non-Intervention

    private static let nonInterventionTasks: [MicroTask] = [
        MicroTask(
            id: "ni-01", cardID: "non-intervention",
            textEN: "The next time someone does something 'wrong', watch your impulse to correct. Just observe it.",
            textDE: "Wenn jemand das nächste Mal etwas ‚falsch' macht, beobachte deinen Impuls zu korrigieren. Beobachte ihn einfach."
        ),
        MicroTask(
            id: "ni-02", cardID: "non-intervention",
            textEN: "When you see something messy or out of place, notice the urge to fix it. Let it be.",
            textDE: "Wenn du etwas Unordentliches siehst, bemerke den Drang, es zu richten. Lass es so."
        ),
        MicroTask(
            id: "ni-03", cardID: "non-intervention",
            textEN: "The next conversation you have — listen without mentally editing what the other person should say.",
            textDE: "Im nächsten Gespräch — höre zu, ohne im Geist zu bearbeiten, was der andere sagen sollte."
        ),
        MicroTask(
            id: "ni-04", cardID: "non-intervention",
            textEN: "When a situation feels uncomfortable, watch yourself wanting to change it. What happens if you don't?",
            textDE: "Wenn sich eine Situation unbequem anfühlt, beobachte, wie du sie ändern willst. Was passiert, wenn du es nicht tust?"
        ),
        MicroTask(
            id: "ni-05", cardID: "non-intervention",
            textEN: "Notice a habit today — biting nails, fidgeting, checking phone. Don't stop it. Just see it.",
            textDE: "Bemerke heute eine Gewohnheit — Nägelkauen, Zappeln, Handy checken. Stoppe sie nicht. Sieh sie einfach."
        ),
        MicroTask(
            id: "ni-06", cardID: "non-intervention",
            textEN: "When someone tells you about a problem, notice the urge to offer solutions. Can you just listen?",
            textDE: "Wenn dir jemand von einem Problem erzählt, bemerke den Drang, Lösungen anzubieten. Kannst du einfach zuhören?"
        ),
        MicroTask(
            id: "ni-07", cardID: "non-intervention",
            textEN: "The next time something annoys you, don't react. Just watch the annoyance. Where is it in the body?",
            textDE: "Wenn dich das nächste Mal etwas nervt, reagiere nicht. Beobachte nur die Verärgerung. Wo ist sie im Körper?"
        ),
        MicroTask(
            id: "ni-08", cardID: "non-intervention",
            textEN: "When plans change unexpectedly, watch the resistance. You don't have to overcome it — just see it.",
            textDE: "Wenn sich Pläne unerwartet ändern, beobachte den Widerstand. Du musst ihn nicht überwinden — sieh ihn einfach."
        ),
    ]

    // MARK: 3. Undivided Perception

    private static let undividedPerceptionTasks: [MicroTask] = [
        MicroTask(
            id: "up-01", cardID: "undivided-perception",
            textEN: "When you make tea or coffee, do it with 100% awareness. Watch your hands, the cup, the water. Nothing else.",
            textDE: "Wenn du Tee oder Kaffee machst, tu es mit 100% Aufmerksamkeit. Beobachte deine Hände, die Tasse, das Wasser. Nichts anderes."
        ),
        MicroTask(
            id: "up-02", cardID: "undivided-perception",
            textEN: "The next time you eat, taste only. No screen, no reading, no planning. Just the food.",
            textDE: "Wenn du das nächste Mal isst, schmecke nur. Kein Bildschirm, kein Lesen, kein Planen. Nur das Essen."
        ),
        MicroTask(
            id: "up-03", cardID: "undivided-perception",
            textEN: "Walk to the next room and let your eyes rest on one thing for 30 seconds. See it completely.",
            textDE: "Geh in den nächsten Raum und lass deinen Blick 30 Sekunden auf einem Ding ruhen. Sieh es vollständig."
        ),
        MicroTask(
            id: "up-04", cardID: "undivided-perception",
            textEN: "The next time you wash your hands, feel only the water. The temperature, the pressure, the sound.",
            textDE: "Wenn du dir das nächste Mal die Hände wäschst, fühle nur das Wasser. Die Temperatur, den Druck, das Geräusch."
        ),
        MicroTask(
            id: "up-05", cardID: "undivided-perception",
            textEN: "Listen to the next sound you hear — fully. Not naming it, not judging it. Just hearing.",
            textDE: "Höre das nächste Geräusch, das du hörst — vollständig. Nicht benennen, nicht bewerten. Nur hören."
        ),
        MicroTask(
            id: "up-06", cardID: "undivided-perception",
            textEN: "The next time you look at a person, really look. Their face, their expression. Without narrating.",
            textDE: "Wenn du das nächste Mal eine Person anschaust, schau wirklich hin. Ihr Gesicht, ihr Ausdruck. Ohne zu kommentieren."
        ),
        MicroTask(
            id: "up-07", cardID: "undivided-perception",
            textEN: "Pick up the next object you touch with full attention. Feel its weight, texture, temperature.",
            textDE: "Nimm den nächsten Gegenstand, den du anfasst, mit voller Aufmerksamkeit auf. Fühle Gewicht, Textur, Temperatur."
        ),
        MicroTask(
            id: "up-08", cardID: "undivided-perception",
            textEN: "The next glass of water you drink — feel only this: lips, liquid, swallowing, coolness.",
            textDE: "Das nächste Glas Wasser, das du trinkst — fühle nur dies: Lippen, Flüssigkeit, Schlucken, Kühle."
        ),
    ]

    // MARK: 4. Unhurried Response

    private static let unhurriedResponseTasks: [MicroTask] = [
        MicroTask(
            id: "ur-01", cardID: "unhurried-response",
            textEN: "The next time someone asks you a question, notice the gap between hearing it and wanting to answer. Who wants to answer?",
            textDE: "Wenn dir das nächste Mal jemand eine Frage stellt, bemerke die Lücke zwischen Hören und Antworten-Wollen. Wer will antworten?"
        ),
        MicroTask(
            id: "ur-02", cardID: "unhurried-response",
            textEN: "Before you type your next message, pause. Feel the impulse to respond. Then respond — or don't.",
            textDE: "Bevor du deine nächste Nachricht tippst, halte inne. Fühle den Impuls zu antworten. Dann antworte — oder nicht."
        ),
        MicroTask(
            id: "ur-03", cardID: "unhurried-response",
            textEN: "The next time you feel criticized, watch the reflex to defend. There's a space before the reaction. Find it.",
            textDE: "Wenn du dich das nächste Mal kritisiert fühlst, beobachte den Reflex, dich zu verteidigen. Vor der Reaktion liegt ein Raum. Finde ihn."
        ),
        MicroTask(
            id: "ur-04", cardID: "unhurried-response",
            textEN: "When your phone vibrates, notice the pull to check. Count to three. Then decide — consciously.",
            textDE: "Wenn dein Handy vibriert, bemerke den Zug, nachzuschauen. Zähle bis drei. Dann entscheide — bewusst."
        ),
        MicroTask(
            id: "ur-05", cardID: "unhurried-response",
            textEN: "In your next conversation, wait one full breath after the other person finishes before you speak.",
            textDE: "Im nächsten Gespräch: Warte einen vollen Atemzug, nachdem der andere fertig ist, bevor du sprichst."
        ),
        MicroTask(
            id: "ur-06", cardID: "unhurried-response",
            textEN: "The next time you feel the urge to share an opinion, pause. Is it the situation asking, or your ego?",
            textDE: "Wenn du den nächsten Drang spürst, eine Meinung zu teilen, halte inne. Fragt die Situation — oder dein Ego?"
        ),
        MicroTask(
            id: "ur-07", cardID: "unhurried-response",
            textEN: "When you're about to interrupt someone, catch yourself. Where did that impulse come from?",
            textDE: "Wenn du jemanden unterbrechen willst, ertappe dich. Woher kam dieser Impuls?"
        ),
        MicroTask(
            id: "ur-08", cardID: "unhurried-response",
            textEN: "The next decision you make today — even a small one — pause and notice what's choosing.",
            textDE: "Die nächste Entscheidung, die du heute triffst — auch eine kleine — halte inne und bemerke, was entscheidet."
        ),
    ]

    // MARK: 5. Intentionlessness

    private static let intentionlessnessTasks: [MicroTask] = [
        MicroTask(
            id: "il-01", cardID: "intentionlessness",
            textEN: "Go for a short walk with no destination. Not for exercise, not for fresh air. Just walk.",
            textDE: "Mach einen kurzen Spaziergang ohne Ziel. Nicht für Bewegung, nicht für frische Luft. Einfach gehen."
        ),
        MicroTask(
            id: "il-02", cardID: "intentionlessness",
            textEN: "Sit for 60 seconds doing absolutely nothing. No goal. Not meditating. Not relaxing. Just sitting.",
            textDE: "Sitze 60 Sekunden und tu absolut nichts. Kein Ziel. Nicht meditieren. Nicht entspannen. Einfach sitzen."
        ),
        MicroTask(
            id: "il-03", cardID: "intentionlessness",
            textEN: "The next thing you do — can you do it without wanting a result? Washing a cup just to wash it.",
            textDE: "Das Nächste, das du tust — kannst du es ohne Ergebniserwartung tun? Eine Tasse spülen, nur um sie zu spülen."
        ),
        MicroTask(
            id: "il-04", cardID: "intentionlessness",
            textEN: "Look out the window. Not to check the weather, not to see anything specific. Just look.",
            textDE: "Schau aus dem Fenster. Nicht um das Wetter zu prüfen, nicht um etwas Bestimmtes zu sehen. Einfach schauen."
        ),
        MicroTask(
            id: "il-05", cardID: "intentionlessness",
            textEN: "Breathe without trying to breathe well. Let the breath be whatever it is.",
            textDE: "Atme, ohne gut atmen zu wollen. Lass den Atem sein, was er ist."
        ),
        MicroTask(
            id: "il-06", cardID: "intentionlessness",
            textEN: "The next time you eat, don't eat to be full. Just eat. One bite at a time.",
            textDE: "Wenn du das nächste Mal isst, iss nicht um satt zu werden. Iss einfach. Ein Bissen nach dem anderen."
        ),
        MicroTask(
            id: "il-07", cardID: "intentionlessness",
            textEN: "Pick up something and put it down. Not because it needs moving. Just to feel the act.",
            textDE: "Nimm etwas hoch und leg es wieder hin. Nicht weil es bewegt werden muss. Nur um die Handlung zu fühlen."
        ),
        MicroTask(
            id: "il-08", cardID: "intentionlessness",
            textEN: "Stand somewhere and do nothing. Not waiting. Not resting. Just standing.",
            textDE: "Steh irgendwo und tu nichts. Nicht warten. Nicht ruhen. Einfach stehen."
        ),
    ]

    // MARK: 6. Presence in Daily Life

    private static let presenceDailyLifeTasks: [MicroTask] = [
        MicroTask(
            id: "pdl-01", cardID: "presence-daily-life",
            textEN: "When you open a door, feel the handle. The temperature, the texture, the turning motion.",
            textDE: "Wenn du eine Tür öffnest, fühle die Klinke. Die Temperatur, die Textur, die Drehbewegung."
        ),
        MicroTask(
            id: "pdl-02", cardID: "presence-daily-life",
            textEN: "The next time you go up or down stairs, feel each step. Heel, sole, toe, lift.",
            textDE: "Wenn du das nächste Mal Treppen steigst, fühle jeden Schritt. Ferse, Sohle, Zehen, Abheben."
        ),
        MicroTask(
            id: "pdl-03", cardID: "presence-daily-life",
            textEN: "When you put on or take off clothes, feel the fabric on your skin. The pulling, the sliding.",
            textDE: "Wenn du dich an- oder ausziehst, fühle den Stoff auf deiner Haut. Das Ziehen, das Gleiten."
        ),
        MicroTask(
            id: "pdl-04", cardID: "presence-daily-life",
            textEN: "During your next shower, feel the water hit your skin. Where is it warm? Where does it run?",
            textDE: "Bei deiner nächsten Dusche: Fühle das Wasser auf deiner Haut. Wo ist es warm? Wohin läuft es?"
        ),
        MicroTask(
            id: "pdl-05", cardID: "presence-daily-life",
            textEN: "The next time you sit down in a chair, feel the moment of contact. The weight settling.",
            textDE: "Wenn du dich das nächste Mal hinsetzt, fühle den Moment des Kontakts. Das Gewicht, das sich senkt."
        ),
        MicroTask(
            id: "pdl-06", cardID: "presence-daily-life",
            textEN: "When you pay for something — tap, card, cash — notice the moment of exchange. What happens inside?",
            textDE: "Wenn du etwas bezahlst — tippen, Karte, Bargeld — bemerke den Moment des Austauschs. Was passiert innen?"
        ),
        MicroTask(
            id: "pdl-07", cardID: "presence-daily-life",
            textEN: "The next time you cook, feel the knife, the board, the ingredients. Each texture, each sound.",
            textDE: "Wenn du das nächste Mal kochst, fühle das Messer, das Brett, die Zutaten. Jede Textur, jedes Geräusch."
        ),
        MicroTask(
            id: "pdl-08", cardID: "presence-daily-life",
            textEN: "When you brush your teeth, feel only that. The bristles, the paste, the motion.",
            textDE: "Beim Zähneputzen fühle nur das. Die Borsten, die Paste, die Bewegung."
        ),
        MicroTask(
            id: "pdl-09", cardID: "presence-daily-life",
            textEN: "The next time you lock or unlock a door, be completely there for those three seconds.",
            textDE: "Wenn du das nächste Mal eine Tür auf- oder abschließt, sei komplett da für diese drei Sekunden."
        ),
        MicroTask(
            id: "pdl-10", cardID: "presence-daily-life",
            textEN: "When you get into a car or onto a bus, notice the transition. Outside to inside. Moving to sitting.",
            textDE: "Wenn du ins Auto oder in den Bus steigst, bemerke den Übergang. Draußen nach drinnen. Gehen zu Sitzen."
        ),
    ]

    // MARK: 7. Silence

    private static let silenceTasks: [MicroTask] = [
        MicroTask(
            id: "si-01", cardID: "silence",
            textEN: "The next pause in a conversation — don't fill it. Let the silence be.",
            textDE: "Die nächste Pause in einem Gespräch — fülle sie nicht. Lass die Stille sein."
        ),
        MicroTask(
            id: "si-02", cardID: "silence",
            textEN: "For the next 5 minutes, don't speak unless spoken to. Not as a rule — as an experiment.",
            textDE: "Sprich die nächsten 5 Minuten nicht, es sei denn, du wirst angesprochen. Nicht als Regel — als Experiment."
        ),
        MicroTask(
            id: "si-03", cardID: "silence",
            textEN: "Turn off all sounds on your devices for 30 minutes. Notice what the silence feels like.",
            textDE: "Schalte alle Geräusche deiner Geräte für 30 Minuten aus. Bemerke, wie sich die Stille anfühlt."
        ),
        MicroTask(
            id: "si-04", cardID: "silence",
            textEN: "The next time you're alone, don't turn on music, podcast, or TV. Listen to the room.",
            textDE: "Wenn du das nächste Mal allein bist, schalte keine Musik, keinen Podcast, keinen Fernseher ein. Höre den Raum."
        ),
        MicroTask(
            id: "si-05", cardID: "silence",
            textEN: "In your next conversation, listen for the silence between the words.",
            textDE: "Im nächsten Gespräch: Höre auf die Stille zwischen den Worten."
        ),
        MicroTask(
            id: "si-06", cardID: "silence",
            textEN: "When you walk outside, stop narrating the world. Just hear it.",
            textDE: "Wenn du draußen gehst, hör auf, die Welt zu kommentieren. Höre sie einfach."
        ),
        MicroTask(
            id: "si-07", cardID: "silence",
            textEN: "Before you sleep tonight, lie in silence for 2 minutes. Not meditating. Just lying quietly.",
            textDE: "Bevor du heute schlafen gehst, liege 2 Minuten in Stille. Nicht meditieren. Einfach ruhig liegen."
        ),
        MicroTask(
            id: "si-08", cardID: "silence",
            textEN: "The next time you want to say something, ask: does this need to be said, or does the silence serve better?",
            textDE: "Wenn du das nächste Mal etwas sagen willst, frage: Muss das gesagt werden, oder dient die Stille besser?"
        ),
    ]
}
