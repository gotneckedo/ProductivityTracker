import Foundation

/// Bundled short reads. All text is original writing created for Still, so no
/// public-domain verification is needed. See ASSET_AND_CONTENT_POLICY.md before
/// adding third-party or public-domain excerpts.
struct BundledReadingLibrary: ReadingContentProviding {
    private static let licenseNote = "Original text written for Still. Not quoted from any other work."

    static let items: [ReadingItem] = [
        ReadingItem(
            id: "read-tea-going-cold",
            title: "Tea Going Cold",
            author: "Still",
            source: "Still original micro-essay",
            paragraphs: [
                "There is a particular cup of tea that almost everyone knows. You make it with good intentions, set it down beside you, and look back an hour later to find it pale and cold, a thin ring marking where it used to be.",
                "It is easy to read that cup as a small failure. You meant to enjoy it and didn't. But it is also a record of something: for an hour, you were somewhere else. Something held you completely enough that warmth stopped mattering.",
                "Most of the day doesn't work like that. Attention skips. It checks the time, the phone, the other tab, the thing someone said this morning. It is less like a beam and more like a moth, visiting every light in the room without resting on one.",
                "The cold cup is proof that the other kind of attention is still available to you. It hasn't gone anywhere. It arrives when there is one thing in front of you and nothing pulling at your sleeve.",
                "So the next time you find one, maybe don't pour it out right away. Hold it for a second. It's the evidence of an hour that belonged to you.",
                "Then make another, and this time drink it while it's warm."
            ],
            license: .originalForStill,
            licenseNote: licenseNote,
            format: .shortText
        ),
        ReadingItem(
            id: "read-defense-of-boredom",
            title: "A Short Defense of Boredom",
            author: "Still",
            source: "Still original micro-essay",
            paragraphs: [
                "Boredom has a bad reputation. We treat it like a draft from an open window: something to close as fast as possible, usually with a screen.",
                "But boredom is not empty. It is the feeling of a mind with nothing assigned to it, slowly remembering that it can assign things to itself. The first minute is uncomfortable. The second minute is restless. Somewhere around the third, something shifts. You notice the sound of the refrigerator, or a question you forgot you had, or the fact that you are a little hungry, or a little sad, or neither.",
                "This is where a lot of ideas come from. Not from the scroll, which fills every gap before it can open, but from the gap itself.",
                "Children know this better than adults do. Leave a child with nothing and, after the complaining, they invent a game with a spoon.",
                "You don't have to invent anything. You only have to let the gap stay open a little longer than feels natural. Nothing bad happens there. It's just quiet, and quiet is where you can hear yourself think."
            ],
            license: .originalForStill,
            licenseNote: licenseNote,
            format: .shortText
        ),
        ReadingItem(
            id: "read-moss",
            title: "Moss Keeps Its Own Time",
            author: "Still",
            source: "Still original micro-essay",
            paragraphs: [
                "Moss grows on the north side of old walls, on the shaded roots of trees, in the cracks of steps nobody sweeps anymore. It grows slowly, and it is in no hurry to be noticed.",
                "When it dries out, it doesn't die. It waits, brittle and brown, sometimes for weeks. Then rain comes, and within hours it is soft and green again, as if nothing happened.",
                "There is something reassuring in that. Not every kind of progress is steady. Some of it looks like nothing for a long time, and then, given the right conditions, returns all at once.",
                "Habits can be like that. You stop for a while. The streak ends, the routine thins out, and it's tempting to decide you've lost it. But the capacity doesn't go anywhere. It is waiting on the wall for rain.",
                "One session is rain. One quiet morning is rain. You don't need to start over. You just need to get a little wet."
            ],
            license: .originalForStill,
            licenseNote: licenseNote,
            format: .shortText
        ),
        ReadingItem(
            id: "read-window-seat",
            title: "The Window Seat",
            author: "Still",
            source: "Still original micro-essay",
            paragraphs: [
                "On a long train ride, the window seat is a small luxury. Nothing is asked of you. The landscape does the work, sliding past in layers: the fence posts quick and close, the fields slower, the hills barely moving at all.",
                "It's a good way to think about a day. The close things rush. Messages, small chores, the next ten minutes. They blur because they are near.",
                "Further back, things move more slowly: the week, the project, the people you're keeping up with. And far off, almost still, are the things that change over years. They are there the whole time, even when the foreground is loud.",
                "You can't stop the train. But you can choose where to rest your eyes. Looking only at the fence posts is exhausting. Look up once in a while, to the hills. They'll still be there when you look back down."
            ],
            license: .originalForStill,
            licenseNote: licenseNote,
            format: .shortText
        )
    ]

    func allItems() -> [ReadingItem] { Self.items }

    func item(id: String) -> ReadingItem? {
        Self.items.first { $0.id == id }
    }
}

enum CreativePromptLibrary {
    static let all: [CreativePrompt] = [
        CreativePrompt(id: "prompt-three-sounds", text: "Describe the room you're in using only three sounds.", guidance: "Three lines is plenty."),
        CreativePrompt(id: "prompt-small-good", text: "Write down one small thing that went right today.", guidance: "A sentence or two."),
        CreativePrompt(id: "prompt-window", text: "What would you see from your ideal window?", guidance: "Five details, no more."),
        CreativePrompt(id: "prompt-letter", text: "Write a two-line note to yourself one year from now.", guidance: "Two lines."),
        CreativePrompt(id: "prompt-object", text: "Pick an object near you. Where has it been before it got here?", guidance: "A short paragraph."),
        CreativePrompt(id: "prompt-weather", text: "If your mood right now were weather, what would the forecast say?", guidance: "One forecast."),
        CreativePrompt(id: "prompt-title", text: "Give today a title, like a chapter in a book.", guidance: "Just the title, or a line under it."),
        CreativePrompt(id: "prompt-color", text: "Name a color you saw today and where you saw it.", guidance: "A sentence or two.")
    ]

    /// One prompt per calendar day, rotating deterministically.
    static func prompt(for date: Date, calendar: Calendar = .current) -> CreativePrompt {
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return all[abs(day) % all.count]
    }
}
