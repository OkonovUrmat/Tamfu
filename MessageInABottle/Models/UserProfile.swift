import Foundation

// MARK: - Country

struct Country: Hashable, Identifiable, Codable {
    let code: String   // ISO 3166-1 alpha-2
    let name: String

    var id: String { code }

    var flag: String {
        code.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(127397 + $0.value) }
            .map { String($0) }
            .joined()
    }

    static let all: [Country] = [
        Country(code: "KG", name: "Kyrgyzstan"), Country(code: "KZ", name: "Kazakhstan"),
        Country(code: "UZ", name: "Uzbekistan"), Country(code: "TR", name: "Türkiye"),
        Country(code: "JP", name: "Japan"), Country(code: "KR", name: "South Korea"),
        Country(code: "BR", name: "Brazil"), Country(code: "AR", name: "Argentina"),
        Country(code: "MX", name: "Mexico"), Country(code: "US", name: "United States"),
        Country(code: "CA", name: "Canada"), Country(code: "GB", name: "United Kingdom"),
        Country(code: "IE", name: "Ireland"), Country(code: "FR", name: "France"),
        Country(code: "DE", name: "Germany"), Country(code: "ES", name: "Spain"),
        Country(code: "PT", name: "Portugal"), Country(code: "IT", name: "Italy"),
        Country(code: "NO", name: "Norway"), Country(code: "IS", name: "Iceland"),
        Country(code: "EG", name: "Egypt"), Country(code: "KE", name: "Kenya"),
        Country(code: "NG", name: "Nigeria"), Country(code: "ZA", name: "South Africa"),
        Country(code: "IN", name: "India"), Country(code: "ID", name: "Indonesia"),
        Country(code: "VN", name: "Vietnam"), Country(code: "TH", name: "Thailand"),
        Country(code: "AU", name: "Australia"), Country(code: "NZ", name: "New Zealand"),
        Country(code: "GE", name: "Georgia"), Country(code: "PL", name: "Poland")
    ].sorted { $0.name < $1.name }

    static func named(_ code: String) -> Country {
        all.first { $0.code == code } ?? Country(code: code, name: code)
    }
}

// MARK: - Profile categories (progressive discovery)

enum ProfileCategory: String, CaseIterable, Identifiable, Codable, Hashable {
    case basics, hobbies, interests, music, moviesBooks, lifestyle, personality, media, additional

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basics: return "Basic information"
        case .hobbies: return "Hobbies"
        case .interests: return "Interests"
        case .music: return "Music"
        case .moviesBooks: return "Movies & books"
        case .lifestyle: return "Lifestyle"
        case .personality: return "Personality"
        case .media: return "Photos & videos"
        case .additional: return "More about me"
        }
    }

    /// Used in sentences like "Alex revealed their hobbies".
    var phrase: String {
        switch self {
        case .basics: return "the basics"
        case .hobbies: return "hobbies"
        case .interests: return "interests"
        case .music: return "favorite music"
        case .moviesBooks: return "favorite movies & books"
        case .lifestyle: return "lifestyle"
        case .personality: return "personality"
        case .media: return "photos & videos"
        case .additional: return "a little more"
        }
    }

    var icon: String {
        switch self {
        case .basics: return "person.text.rectangle"
        case .hobbies: return "paintpalette"
        case .interests: return "sparkles"
        case .music: return "music.note"
        case .moviesBooks: return "book.closed"
        case .lifestyle: return "leaf"
        case .personality: return "theatermasks"
        case .media: return "photo.on.rectangle"
        case .additional: return "ellipsis.bubble"
        }
    }
}

enum CategoryVisibility: String, CaseIterable, Identifiable, Codable {
    case `public`, gradual, hidden
    var id: String { rawValue }

    var title: String {
        switch self {
        case .public: return "Public"
        case .gradual: return "In chats"
        case .hidden: return "Hidden"
        }
    }

    var explanation: String {
        switch self {
        case .public: return "Visible on your profile to everyone allowed to see it."
        case .gradual: return "Only shared when you choose to reveal it in a chat."
        case .hidden: return "Never shown and can't be revealed."
        }
    }

    var icon: String {
        switch self {
        case .public: return "globe"
        case .gradual: return "lock.open"
        case .hidden: return "eye.slash"
        }
    }
}

// MARK: - Profile details

struct ProfileDetails: Hashable, Codable {
    var occupation: String = ""
    var music: [String] = []
    var moviesBooks: [String] = []
    var lifestyle: [String] = []
    var personality: [String] = []
    var additional: [String] = []
}

// MARK: - User profile

struct UserProfile: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var birthDate: Date
    var country: Country
    var city: String
    var bio: String
    var status: String
    var languages: [String]
    var interests: [String]
    var hobbies: [String]
    var photos: [MediaItem]
    var videos: [MediaItem]
    var details: ProfileDetails
    var categoryVisibility: [ProfileCategory: CategoryVisibility]
    var isOnline: Bool
    var lastActive: Date
    var avatarSeed: Int

    init(
        id: UUID = UUID(),
        name: String,
        birthDate: Date,
        country: Country,
        city: String,
        bio: String = "",
        status: String = "",
        languages: [String] = [],
        interests: [String] = [],
        hobbies: [String] = [],
        photos: [MediaItem] = [],
        videos: [MediaItem] = [],
        details: ProfileDetails = ProfileDetails(),
        categoryVisibility: [ProfileCategory: CategoryVisibility] = UserProfile.defaultVisibility,
        isOnline: Bool = false,
        lastActive: Date = .now,
        avatarSeed: Int = Int.random(in: 0...100)
    ) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.country = country
        self.city = city
        self.bio = bio
        self.status = status
        self.languages = languages
        self.interests = interests
        self.hobbies = hobbies
        self.photos = photos
        self.videos = videos
        self.details = details
        self.categoryVisibility = categoryVisibility
        self.isOnline = isOnline
        self.lastActive = lastActive
        self.avatarSeed = avatarSeed
    }

    static let defaultVisibility: [ProfileCategory: CategoryVisibility] = [
        .basics: .public, .hobbies: .gradual, .interests: .public, .music: .gradual,
        .moviesBooks: .gradual, .lifestyle: .gradual, .personality: .gradual,
        .media: .gradual, .additional: .hidden
    ]

    // MARK: Derived

    var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 0
    }

    var isAdult: Bool { age >= 18 }

    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first }.map { String($0) }.joined().uppercased()
    }

    /// Age bracket used in anonymous teasers ("20s").
    var ageBracket: String {
        let decade = (age / 10) * 10
        return age < 20 ? "late teens" : "\(decade)s"
    }

    var locationLine: String {
        city.isEmpty ? "\(country.flag) \(country.name)" : "\(country.flag) \(city), \(country.name)"
    }

    var avatar: MediaItem? { photos.first }

    var ref: UserRef { UserRef(id: id, name: name, avatarSeed: avatarSeed, avatar: avatar) }

    func visibility(of category: ProfileCategory) -> CategoryVisibility {
        categoryVisibility[category] ?? .gradual
    }

    /// Human-readable items shown when a category is revealed.
    func items(for category: ProfileCategory) -> [String] {
        switch category {
        case .basics:
            var items = ["\(age) years old", "\(city.isEmpty ? "" : city + ", ")\(country.name)"]
            if !details.occupation.isEmpty { items.append(details.occupation) }
            if !languages.isEmpty { items.append("Speaks " + languages.joined(separator: ", ")) }
            return items
        case .hobbies: return hobbies
        case .interests: return interests
        case .music: return details.music
        case .moviesBooks: return details.moviesBooks
        case .lifestyle: return details.lifestyle
        case .personality: return details.personality
        case .media: return ["\(photos.count) photos", "\(videos.count) videos"]
        case .additional: return details.additional
        }
    }

    func hasContent(for category: ProfileCategory) -> Bool {
        switch category {
        case .media: return !photos.isEmpty || !videos.isEmpty
        default: return !items(for: category).isEmpty
        }
    }

    /// Categories that are only shared in chats ("In chats" visibility).
    var discoverableCategories: [ProfileCategory] {
        ProfileCategory.allCases.filter { visibility(of: $0) == .gradual && hasContent(for: $0) }
    }

    /// Categories this user can voluntarily reveal in a chat.
    var revealableCategories: [ProfileCategory] {
        ProfileCategory.allCases.filter { visibility(of: $0) != .hidden && hasContent(for: $0) }
    }
}
