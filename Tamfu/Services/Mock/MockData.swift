import Foundation

/// Realistic mock content used until the backend exists.
enum MockData {

    static func birthDate(age: Int) -> Date {
        let days = Int.random(in: 10...300)
        return Calendar.current.date(byAdding: .day, value: -(age * 365 + days), to: .now) ?? .now
    }

    static let allLanguages = ["English", "Russian", "Kyrgyz", "Kazakh", "Turkish", "Japanese", "Korean",
                               "Spanish", "Portuguese", "French", "German", "Italian", "Arabic", "Hindi",
                               "Norwegian", "Polish", "Vietnamese", "Swahili", "Georgian", "Uzbek"]

    static let allInterests = ["Photography", "Psychology", "Astronomy", "Architecture", "Languages",
                               "History", "Philosophy", "Startups", "Design", "Climate", "Food culture",
                               "Anime", "Football", "Cinema", "Poetry", "Space", "Fashion", "Tech",
                               "Ocean life", "Mountains"]

    static let allHobbies = ["Hiking", "Cooking", "Surfing", "Guitar", "Running", "Drawing", "Yoga",
                             "Chess", "Gaming", "Baking", "Climbing", "Reading", "Film photography",
                             "Dancing", "Cycling", "Gardening", "Pottery", "Skateboarding", "Swimming", "Writing"]

    static let moods = ["Daydreaming about the sea 🌊", "Learning to cook plov", "New city, new me",
                        "Collecting sunsets", "Coffee-powered ☕️", "Looking for book recs",
                        "Just finished a long hike", "Practicing my Spanish", "Night owl mode 🌙",
                        "Missing summer"]

    // MARK: Current (demo) user

    static func demoUser() -> UserProfile {
        UserProfile(
            name: "Urmat Okonov",
            birthDate: birthDate(age: 26),
            country: Country.named("KG"),
            city: "Bishkek",
            bio: "Mountains outside, code inside. Looking for stories from places I've never been.",
            status: "Planning a trip to Issyk-Kul 🏔️",
            languages: ["Kyrgyz", "Russian", "English"],
            interests: ["Tech", "Mountains", "Photography", "Startups"],
            hobbies: ["Hiking", "Chess", "Film photography", "Cooking"],
            photos: [.remotePhoto("urmat-1"), .remotePhoto("urmat-2"), .remotePhoto("urmat-3")],
            videos: [.sampleVideo(posterSeed: "urmat-video")],
            details: ProfileDetails(
                occupation: "iOS developer",
                music: ["Lo-fi beats", "Kyrgyz folk", "Coldplay", "Hans Zimmer"],
                moviesBooks: ["Interstellar", "The Little Prince", "Jamilia — Chingiz Aitmatov"],
                lifestyle: ["Early riser", "Loves tea more than coffee", "Weekend hikes"],
                personality: ["Curious", "Calm", "Good listener", "Ambivert"],
                additional: ["Has visited 9 countries", "Dreams of seeing the northern lights"]
            ),
            isOnline: true,
            avatarSeed: 1
        )
    }

    // MARK: Community

    static func community() -> [UserProfile] {
        [
            make("Maria Santos", 27, "BR", "Florianópolis", seed: 2,
                 bio: "Surf in the morning, design in the afternoon, samba at night.",
                 status: "Collecting sunsets", langs: ["Portuguese", "English", "Spanish"],
                 interests: ["Design", "Ocean life", "Climate"], hobbies: ["Surfing", "Dancing", "Drawing"],
                 occupation: "Product designer",
                 music: ["Bossa nova", "Anitta", "Tame Impala"], movies: ["City of God", "Amélie", "One Hundred Years of Solitude"],
                 lifestyle: ["Beach > city", "Vegetarian"], personality: ["Optimist", "Spontaneous"],
                 additional: ["Speaks to her plants"], online: true),
            make("Kenji Watanabe", 31, "JP", "Kyoto", seed: 3,
                 bio: "Tea ceremony student. Film camera always in my bag.",
                 status: "Looking for book recs", langs: ["Japanese", "English"],
                 interests: ["Photography", "Architecture", "History"], hobbies: ["Film photography", "Cycling", "Pottery"],
                 occupation: "Architect",
                 music: ["Ryuichi Sakamoto", "City pop", "Nujabes"], movies: ["Perfect Days", "Norwegian Wood"],
                 lifestyle: ["Minimalist", "Bikes everywhere"], personality: ["Quiet", "Observant", "Dry humor"],
                 additional: ["Has a cat named Mochi"], online: false),
            make("Aigerim Nurlanova", 24, "KZ", "Almaty", seed: 4,
                 bio: "Med student who escapes to the mountains every weekend.",
                 status: "Coffee-powered ☕️", langs: ["Kazakh", "Russian", "English"],
                 interests: ["Psychology", "Mountains", "Languages"], hobbies: ["Hiking", "Yoga", "Reading"],
                 occupation: "Medical student",
                 music: ["Dimash", "Adele", "Indie folk"], movies: ["Pride & Prejudice", "Inside Out"],
                 lifestyle: ["Night shifts", "Early hikes"], personality: ["Empathetic", "Determined"],
                 additional: ["Wants to work with Doctors Without Borders"], online: true),
            make("Lucas Moreau", 29, "FR", "Lyon", seed: 5,
                 bio: "Baker by passion, engineer by profession. Ask me about sourdough.",
                 status: "Practicing my Spanish", langs: ["French", "English", "Spanish"],
                 interests: ["Food culture", "Tech", "Cinema"], hobbies: ["Baking", "Running", "Guitar"],
                 occupation: "Software engineer",
                 music: ["Daft Punk", "Édith Piaf", "Jazz"], movies: ["Ratatouille", "The Intouchables"],
                 lifestyle: ["Marathon training", "Market Sundays"], personality: ["Warm", "Talkative"],
                 additional: ["Has baked bread in 6 countries"], online: false),
            make("Amara Okafor", 26, "NG", "Lagos", seed: 6,
                 bio: "Writing a novel, one coffee at a time. Afrobeats enthusiast.",
                 status: "Night owl mode 🌙", langs: ["English", "French"],
                 interests: ["Poetry", "Fashion", "Startups"], hobbies: ["Writing", "Dancing", "Reading"],
                 occupation: "Writer & copywriter",
                 music: ["Burna Boy", "Tems", "Sade"], movies: ["Half of a Yellow Sun", "Black Panther"],
                 lifestyle: ["Night owl", "Always has a notebook"], personality: ["Bold", "Funny"],
                 additional: ["First novel coming in 2027"], online: true),
            make("Sofia Lindqvist", 33, "NO", "Tromsø", seed: 7,
                 bio: "I chase the northern lights for a living. Literally.",
                 status: "Daydreaming about the sea 🌊", langs: ["Norwegian", "English", "German"],
                 interests: ["Space", "Astronomy", "Photography"], hobbies: ["Swimming", "Climbing", "Film photography"],
                 occupation: "Aurora guide",
                 music: ["Aurora", "Sigur Rós", "Röyksopp"], movies: ["The Secret Life of Walter Mitty"],
                 lifestyle: ["Cold water swimmer", "Lives by the fjord"], personality: ["Adventurous", "Calm"],
                 additional: ["Has seen 400+ auroras"], online: false),
            make("Diego Hernández", 28, "MX", "Oaxaca", seed: 8,
                 bio: "Chef. I believe every problem can be solved with mole.",
                 status: "Just finished a long hike", langs: ["Spanish", "English"],
                 interests: ["Food culture", "History", "Cinema"], hobbies: ["Cooking", "Guitar", "Hiking"],
                 occupation: "Chef",
                 music: ["Natalia Lafourcade", "Mariachi", "Bad Bunny"], movies: ["Coco", "Roma"],
                 lifestyle: ["Market mornings", "Family dinners"], personality: ["Generous", "Loud laugh"],
                 additional: ["Grandma's recipes in a notebook"], online: true),
            make("Ji-woo Park", 23, "KR", "Busan", seed: 9,
                 bio: "Illustrator. Drawing the ocean every day for a year.",
                 status: "New city, new me", langs: ["Korean", "English", "Japanese"],
                 interests: ["Anime", "Design", "Ocean life"], hobbies: ["Drawing", "Skateboarding", "Gaming"],
                 occupation: "Illustrator",
                 music: ["IU", "NewJeans", "Joe Hisaishi"], movies: ["Spirited Away", "Little Forest"],
                 lifestyle: ["Sketchbook everywhere", "Late breakfasts"], personality: ["Dreamy", "Shy at first"],
                 additional: ["Day 212 of 365"], online: false),
            make("Elif Yılmaz", 30, "TR", "Istanbul", seed: 10,
                 bio: "Historian who gives the best ferry tours of the Bosphorus.",
                 status: "Missing summer", langs: ["Turkish", "English", "German"],
                 interests: ["History", "Architecture", "Languages"], hobbies: ["Reading", "Cycling", "Baking"],
                 occupation: "Historian",
                 music: ["Sezen Aksu", "Jazz", "Classical"], movies: ["Winter Sleep", "Midnight in Paris"],
                 lifestyle: ["Ferry commuter", "Simit lover"], personality: ["Storyteller", "Curious"],
                 additional: ["Owns 600+ books"], online: true),
            make("Noah Williams", 35, "NZ", "Wellington", seed: 11,
                 bio: "Marine biologist. I talk to dolphins (they rarely answer).",
                 status: "Daydreaming about the sea 🌊", langs: ["English"],
                 interests: ["Ocean life", "Climate", "Space"], hobbies: ["Surfing", "Swimming", "Gardening"],
                 occupation: "Marine biologist",
                 music: ["Fat Freddy's Drop", "Bon Iver"], movies: ["My Octopus Teacher", "Moana"],
                 lifestyle: ["Wetsuit is my second skin"], personality: ["Patient", "Nerdy"],
                 additional: ["Tagged 30 sea turtles"], online: false),
            make("Priya Sharma", 27, "IN", "Bengaluru", seed: 12,
                 bio: "Startup founder learning to slow down. Chai > everything.",
                 status: "Coffee-powered ☕️", langs: ["Hindi", "English"],
                 interests: ["Startups", "Psychology", "Tech"], hobbies: ["Yoga", "Running", "Cooking"],
                 occupation: "Founder",
                 music: ["A.R. Rahman", "Prateek Kuhad"], movies: ["Zindagi Na Milegi Dobara", "Atomic Habits"],
                 lifestyle: ["5am club (sometimes)"], personality: ["Driven", "Warm"],
                 additional: ["Building an edtech for villages"], online: true),
            make("Nino Beridze", 25, "GE", "Tbilisi", seed: 13,
                 bio: "Polyphonic singer and wine-region tour guide.",
                 status: "Learning to cook plov", langs: ["Georgian", "Russian", "English"],
                 interests: ["Food culture", "History", "Poetry"], hobbies: ["Dancing", "Hiking", "Cooking"],
                 occupation: "Tour guide",
                 music: ["Georgian polyphony", "Katie Melua"], movies: ["Tangerines", "Before Sunrise"],
                 lifestyle: ["Sunday supra with family"], personality: ["Hospitable", "Lively"],
                 additional: ["Can make khachapuri blindfolded"], online: false),
            make("Tom Becker", 41, "DE", "Hamburg", seed: 14,
                 bio: "Sailor, dad of two, occasional jazz pianist.",
                 status: "Collecting sunsets", langs: ["German", "English"],
                 interests: ["Ocean life", "Cinema", "History"], hobbies: ["Sailing", "Reading", "Cycling"],
                 occupation: "Ship engineer",
                 music: ["Bill Evans", "Kraftwerk"], movies: ["Das Boot", "Master and Commander"],
                 lifestyle: ["Weekends on the water"], personality: ["Steady", "Kind"],
                 additional: ["Crossed the Atlantic twice"], online: true)
        ]
    }

    private static func make(_ name: String, _ age: Int, _ cc: String, _ city: String, seed: Int,
                             bio: String, status: String, langs: [String], interests: [String],
                             hobbies: [String], occupation: String, music: [String], movies: [String],
                             lifestyle: [String], personality: [String], additional: [String],
                             online: Bool) -> UserProfile {
        let slug = name.lowercased().replacingOccurrences(of: " ", with: "-")
        return UserProfile(
            name: name,
            birthDate: birthDate(age: age),
            country: Country.named(cc),
            city: city,
            bio: bio,
            status: status,
            languages: langs,
            interests: interests,
            hobbies: hobbies,
            photos: (1...4).map { MediaItem.remotePhoto("\(slug)-\($0)") },
            videos: seed % 2 == 0 ? [MediaItem.sampleVideo(posterSeed: "\(slug)-v")] : [],
            details: ProfileDetails(occupation: occupation, music: music, moviesBooks: movies,
                                    lifestyle: lifestyle, personality: personality, additional: additional),
            categoryVisibility: communityVisibility,
            isOnline: online,
            lastActive: Date.now.addingTimeInterval(-Double.random(in: 60...86_400)),
            avatarSeed: seed
        )
    }

    /// Typical setup: photos & interests public, the rest discovered in chats.
    static let communityVisibility: [ProfileCategory: CategoryVisibility] = [
        .basics: .public, .interests: .public, .media: .public, .hobbies: .gradual,
        .music: .gradual, .moviesBooks: .gradual, .lifestyle: .gradual,
        .personality: .gradual, .additional: .gradual
    ]

    // MARK: Bottle texts

    static let bottleTexts: [String] = [
        "What's something that made you happy today?",
        "Greetings from the other side of the world! It's 3am and I can't sleep. What are you up to?",
        "Does anyone else feel like time is moving too fast?",
        "If you could teleport anywhere for one hour, where would you go?",
        "I just watched the sunrise over the ocean for the first time. Sending you a little of it 🌅",
        "Tell me one word in your language that you love.",
        "What's the best meal you've ever had? I'm collecting recommendations.",
        "Hello stranger. I hope your day is kinder than mine was. What's your small win today?",
        "I'm learning to play guitar at 30. Is it ever too late to start something?",
        "Send me a song I should listen to tonight 🎧"
    ]

    static let partnerReplies: [String] = [
        "Haha I love that 😄",
        "Wait, really? Tell me more!",
        "That's such a nice way to think about it.",
        "Honestly same. Where are you writing from right now?",
        "I didn't expect a bottle to bring me here, but I'm glad it did.",
        "What time is it there? Here the sun is just going down.",
        "That reminds me of my grandmother — she used to say the same thing.",
        "Okay, now I'm curious about you 👀",
        "Good question… give me a second to think.",
        "You have a really interesting way of seeing things."
    ]
}
