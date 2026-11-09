import Foundation

/// Content for mini-games. Bundled locally; can later be served remotely
/// (A/B tests, localisation, seasonal packs) without changing the UI.
enum GameLibrary {

    static let questions: [QuestionCategory: [String]] = [
        .love: [
            "What does a perfect slow Sunday with someone look like to you?",
            "What's a small gesture that means a lot to you?",
            "Do you believe in love at first sight — or at first conversation?",
            "What's the most important thing you've learned from a past relationship?"
        ],
        .personality: [
            "What disappoints you most often in other people?",
            "What's a compliment you've never forgotten?",
            "Are you more of a planner or an improviser?",
            "What do people usually get wrong about you at first?"
        ],
        .childhood: [
            "What smell instantly takes you back to childhood?",
            "What did you want to be when you were seven?",
            "What's a rule from your childhood home you still follow?",
            "What was your favorite hiding place as a kid?"
        ],
        .philosophy: [
            "Is it better to be loved or understood?",
            "If you could know the absolute truth to one question, what would you ask?",
            "Does everything happen for a reason?",
            "What does a meaningful life mean to you?"
        ],
        .travel: [
            "Would you rather travel around the world or live in one place forever?",
            "What's a place that changed how you see the world?",
            "Window seat or aisle — and why?",
            "Which city would you move to tomorrow if you could?"
        ],
        .dreams: [
            "What's a goal you've never said out loud?",
            "Where do you hope to be waking up in five years?",
            "What would you do if you knew you couldn't fail?",
            "What skill do you wish you could learn overnight?"
        ],
        .funny: [
            "What's the weirdest food combination you secretly love?",
            "If animals could talk, which would be the rudest?",
            "What's your most useless talent?",
            "What would your autobiography be called?"
        ],
        .deep: [
            "What is something you would like to change about your past?",
            "When did you last feel truly at peace?",
            "What's something you're still learning to forgive yourself for?",
            "What do you need more of in your life right now?"
        ]
    ]

    static func randomQuestion(in category: QuestionCategory) -> String {
        if category == .random {
            return questions.values.flatMap { $0 }.randomElement() ?? "What made you smile today?"
        }
        return questions[category]?.randomElement() ?? "What made you smile today?"
    }

    static let wouldYouRather: [(String, String)] = [
        ("Live by the ocean", "Live in the mountains"),
        ("Be able to speak every language", "Be able to talk to animals"),
        ("Travel 100 years into the past", "Travel 100 years into the future"),
        ("Always know when someone is lying", "Always get away with lying"),
        ("Have a personal chef", "Have a personal driver"),
        ("Read minds for a day", "Be invisible for a day"),
        ("Never use social media again", "Never watch a movie again"),
        ("Explore the deep ocean", "Explore outer space"),
        ("Have endless summer", "Have endless winter evenings with snow")
    ]

    static func randomWouldYouRather() -> (String, String) {
        wouldYouRather.randomElement() ?? ("Tea", "Coffee")
    }

    static let challenges: [String] = [
        "Send a photo of the view from your window right now 🪟",
        "Describe your day using only three emojis",
        "Teach each other one word in your native language",
        "Share the last song you listened to — no skipping embarrassing ones",
        "Send a photo of something blue near you",
        "Write a two-line poem about the other person's city",
        "Tell a joke from your country (translations welcome)",
        "Recommend one book or movie in 10 words or less"
    ]

    static func randomChallenge() -> String {
        challenges.randomElement() ?? "Say hi in your native language"
    }

    // MARK: Simulated partner content (mock backend only)

    static let partnerAnswers: [String] = [
        "Honestly? Probably the sound of rain on the window while I'm reading.",
        "Hmm, that's a hard one. I'd say being around people who don't pretend.",
        "When I was little I wanted to be an astronaut. Now I'm happy just looking at the stars.",
        "I think about this more than I'd like to admit 😅",
        "Definitely the ocean. It's where I feel most like myself.",
        "Freedom to choose my own mornings.",
        "Something simple — a long dinner with friends and no phones."
    ]

    static let partnerTwoTruths: [[String]] = [
        ["I've swum with whale sharks", "I can't whistle", "I once met a famous astronaut"],
        ["I've lived in 4 countries", "I'm afraid of butterflies", "I won a pie-eating contest"],
        ["I learned to drive at 25", "I have a twin brother", "I've never seen snow"]
    ]
}
