import SwiftUI

// MARK: - Practice Card Model
// Seven daily mindfulness practice cards, each with a distinct contemplative theme
// and color. Cards are assigned randomly (avoiding yesterday's card) and optionally
// delivered as a morning notification.

struct PracticeCard: Identifiable {
    let id: String                 // e.g. "letting-go"
    let titleDE: String            // "Übung des Loslassens"
    let titleEN: String            // "Exercise of Letting Go"
    let shortTitleDE: String       // "Loslassen" — compact form for watchOS / complications
    let shortTitleEN: String       // "Letting Go"
    let descriptionDE: String      // Full philosophical background / instructions
    let descriptionEN: String
    let promptDE: String           // Short assignment for notifications
    let promptEN: String
    let color: Color               // Distinct card color

    /// Localized full title based on current locale
    var localizedTitle: String {
        Locale.current.language.languageCode?.identifier == "de" ? titleDE : titleEN
    }

    /// Localized short title for compact spaces (watchOS, complications)
    var localizedShortTitle: String {
        Locale.current.language.languageCode?.identifier == "de" ? shortTitleDE : shortTitleEN
    }

    /// Localized description based on current locale
    var localizedDescription: String {
        Locale.current.language.languageCode?.identifier == "de" ? descriptionDE : descriptionEN
    }

    /// Localized short prompt for notifications
    var localizedPrompt: String {
        Locale.current.language.languageCode?.identifier == "de" ? promptDE : promptEN
    }
}

// MARK: - The 7 Practice Cards

extension PracticeCard {
    static let allCards: [PracticeCard] = [
        // 1. Letting Go — Warm amber
        PracticeCard(
            id: "letting-go",
            titleDE: "Übung des Loslassens",
            titleEN: "Exercise of Letting Go",
            shortTitleDE: "Loslassen",
            shortTitleEN: "Letting Go",
            descriptionDE: """
                Loslassen bedeutet nicht Gleichgültigkeit. Es bedeutet, die Dinge zu halten \
                wie Wasser in offenen Händen — präsent, aber ohne zu klammern. Heute übe, \
                das Ergebnis von Handlungen nicht festzuhalten. Beobachte den Impuls, \
                kontrollieren zu wollen, und lass ihn vorbeiziehen wie eine Wolke.
                """,
            descriptionEN: """
                Letting go does not mean indifference. It means holding things like water \
                in open hands — present, but without grasping. Today, practice not clinging \
                to the outcome of your actions. Observe the impulse to control, and let it \
                pass like a cloud.
                """,
            promptDE: "Beobachte heute den Impuls, Ergebnisse festzuhalten — und lass los.",
            promptEN: "Today, observe the impulse to hold on to outcomes — and let go.",
            color: Color(red: 0.77, green: 0.58, blue: 0.42) // #C4956A warm amber
        ),

        // 2. Non-Intervention — Sage green
        PracticeCard(
            id: "non-intervention",
            titleDE: "Übung des Nicht-eingreifens",
            titleEN: "Exercise of Non-Intervention",
            shortTitleDE: "Nicht-eingreifen",
            shortTitleEN: "Non-Intervention",
            descriptionDE: """
                Nicht-eingreifen heißt nicht Untätigkeit. Es heißt, den Impuls zu bemerken, \
                etwas korrigieren oder reparieren zu wollen — und dann zu beobachten, was \
                passiert, wenn du es nicht tust. Die Welt dreht sich auch ohne dein Eingreifen. \
                Heute übe, Beobachter zu sein statt Korrektor.
                """,
            descriptionEN: """
                Non-intervention does not mean inaction. It means noticing the impulse to \
                correct or fix — and then observing what happens when you don't. The world \
                keeps turning without your interference. Today, practice being the observer \
                rather than the corrector.
                """,
            promptDE: "Beobachte heute den Impuls, korrigieren zu wollen — und greife nicht ein.",
            promptEN: "Today, notice the urge to correct — and don't intervene.",
            color: Color(red: 0.48, green: 0.62, blue: 0.49) // #7A9E7E sage green
        ),

        // 3. Undivided Perception — Deep blue
        PracticeCard(
            id: "undivided-perception",
            titleDE: "Übung der ungeteilten Wahrnehmung",
            titleEN: "Exercise of Undivided Perception",
            shortTitleDE: "Ungeteilte Wahrnehmung",
            shortTitleEN: "Undivided Perception",
            descriptionDE: """
                Ungeteilte Wahrnehmung bedeutet, einer Sache die volle Aufmerksamkeit zu \
                schenken — ohne gleichzeitig zu planen, zu bewerten oder abzuschweifen. \
                Heute übe, bei einer alltäglichen Handlung vollständig anwesend zu sein. \
                Nicht Multitasking, sondern Uni-Tasking. Eine Sache. Ganz.
                """,
            descriptionEN: """
                Undivided perception means giving one thing your full attention — without \
                simultaneously planning, judging, or wandering. Today, practice being \
                completely present during an ordinary activity. Not multitasking, but \
                uni-tasking. One thing. Completely.
                """,
            promptDE: "Schenke heute einer alltäglichen Handlung deine volle, ungeteilte Aufmerksamkeit.",
            promptEN: "Today, give one ordinary activity your full, undivided attention.",
            color: Color(red: 0.36, green: 0.48, blue: 0.65) // #5B7BA5 deep blue
        ),

        // 4. Unhurried Response — Dusty rose
        PracticeCard(
            id: "unhurried-response",
            titleDE: "Übung der Antwort ohne Eile",
            titleEN: "Exercise of Unhurried Response",
            shortTitleDE: "Antwort ohne Eile",
            shortTitleEN: "Unhurried Response",
            descriptionDE: """
                Zwischen Reiz und Reaktion liegt ein Raum. In diesem Raum liegt unsere \
                Freiheit. Heute übe, diesen Raum zu finden — den Moment zwischen dem \
                Impuls zu antworten und der Antwort selbst. Nicht Langsamkeit, sondern \
                Bewusstheit.
                """,
            descriptionEN: """
                Between stimulus and response there is a space. In that space lies our \
                freedom. Today, practice finding that space — the moment between the \
                impulse to respond and the response itself. Not slowness, but awareness.
                """,
            promptDE: "Finde heute den Raum zwischen Impuls und Reaktion.",
            promptEN: "Today, find the space between impulse and response.",
            color: Color(red: 0.69, green: 0.49, blue: 0.56) // #B07D8E dusty rose
        ),

        // 5. Intentionlessness — Soft violet
        PracticeCard(
            id: "intentionlessness",
            titleDE: "Übung der Absichtslosigkeit",
            titleEN: "Exercise of Intentionlessness",
            shortTitleDE: "Absichtslosigkeit",
            shortTitleEN: "Intentionlessness",
            descriptionDE: """
                Absichtslosigkeit bedeutet, etwas zu tun, ohne ein Ziel damit zu verfolgen. \
                Nicht gehen, um irgendwo anzukommen. Nicht atmen, um sich zu beruhigen. \
                Einfach tun. Heute übe, eine Handlung von ihrem Zweck zu lösen. Tu etwas, \
                nur um es zu tun.
                """,
            descriptionEN: """
                Intentionlessness means doing something without pursuing a goal. Not walking \
                to get somewhere. Not breathing to calm down. Just doing. Today, practice \
                separating an action from its purpose. Do something just to do it.
                """,
            promptDE: "Tu heute etwas nur um des Tuns willen — ohne Ziel, ohne Zweck.",
            promptEN: "Today, do something just for the sake of doing it — no goal, no purpose.",
            color: Color(red: 0.56, green: 0.49, blue: 0.67) // #8E7EAA soft violet
        ),

        // 6. Presence in Daily Life — Earthy terracotta
        PracticeCard(
            id: "presence-daily-life",
            titleDE: "Übung der Präsenz im Alltag",
            titleEN: "Exercise of Presence in Daily Life",
            shortTitleDE: "Präsenz im Alltag",
            shortTitleEN: "Daily Presence",
            descriptionDE: """
                Präsenz braucht keine besondere Umgebung. Jeder Moment ist ein Tor zur \
                Achtsamkeit — das Öffnen einer Tür, das Treppensteigen, das Anfassen \
                eines Gegenstands. Heute übe, in gewöhnlichen Momenten vollständig da \
                zu sein. Die Meditation ist nicht auf dem Kissen — sie ist überall.
                """,
            descriptionEN: """
                Presence needs no special setting. Every moment is a gateway to awareness — \
                opening a door, climbing stairs, touching an object. Today, practice being \
                fully present in ordinary moments. The meditation is not on the cushion — \
                it is everywhere.
                """,
            promptDE: "Sei heute in einem gewöhnlichen Moment vollständig anwesend.",
            promptEN: "Today, be fully present in one ordinary moment.",
            color: Color(red: 0.71, green: 0.45, blue: 0.35) // #B5735A earthy terracotta
        ),

        // 7. Silence — Muted slate
        PracticeCard(
            id: "silence",
            titleDE: "Übung der Stille",
            titleEN: "Exercise of Silence",
            shortTitleDE: "Stille",
            shortTitleEN: "Silence",
            descriptionDE: """
                Stille ist nicht die Abwesenheit von Geräuschen — sie ist die Anwesenheit \
                von Aufmerksamkeit. Heute übe, Stille zu finden: in Gesprächen, in Pausen, \
                in den Räumen zwischen den Worten. Nicht Schweigen als Disziplin, sondern \
                Stille als Entdeckung.
                """,
            descriptionEN: """
                Silence is not the absence of sound — it is the presence of attention. \
                Today, practice finding silence: in conversations, in pauses, in the spaces \
                between words. Not silence as discipline, but silence as discovery.
                """,
            promptDE: "Finde heute die Stille zwischen den Worten und in den Pausen.",
            promptEN: "Today, find the silence between words and in the pauses.",
            color: Color(red: 0.42, green: 0.50, blue: 0.56) // #6B7F8E muted slate
        )
    ]

    /// Find a card by its ID
    static func card(withID id: String) -> PracticeCard? {
        allCards.first { $0.id == id }
    }
}
