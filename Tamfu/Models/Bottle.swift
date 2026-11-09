import Foundation

/// What the user composes before sending.
struct BottleDraft: Hashable {
    var text: String = ""
    var media: [MediaItem] = []

    var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isEmpty: Bool { trimmedText.isEmpty && media.isEmpty }

    static let maxLength = 500
    static let maxMedia = 3
}

/// A message travelling through the random distribution system.
struct BottleMessage: Identifiable, Hashable, Codable {
    let id: UUID
    let senderID: UUID
    var text: String
    var media: [MediaItem]
    let createdAt: Date
    var expiresAt: Date
    var status: BottleStatus
    /// How many recipients have already been offered this bottle.
    var deliveryAttempts: Int
    /// Users who skipped it — never offered to them again.
    var skippedBy: Set<UUID>
    var currentRecipientID: UUID?
    /// Where it was eventually found (for the sender's history).
    var foundIn: Country?

    init(id: UUID = UUID(), senderID: UUID, text: String, media: [MediaItem],
         createdAt: Date = .now, lifetime: TimeInterval = BottleRules.lifetime) {
        self.id = id
        self.senderID = senderID
        self.text = text
        self.media = media
        self.createdAt = createdAt
        self.expiresAt = createdAt.addingTimeInterval(lifetime)
        self.status = .drifting
        self.deliveryAttempts = 0
        self.skippedBy = []
        self.currentRecipientID = nil
        self.foundIn = nil
    }

    var isExpired: Bool {
        Date.now >= expiresAt || deliveryAttempts >= BottleRules.maxDeliveryAttempts
    }
}

enum BottleStatus: String, Codable, Hashable {
    case drifting, delivered, accepted, expired

    var title: String {
        switch self {
        case .drifting: return "Drifting"
        case .delivered: return "Washed ashore"
        case .accepted: return "Found"
        case .expired: return "Sank"
        }
    }

    var icon: String {
        switch self {
        case .drifting: return "water.waves"
        case .delivered: return "beach.umbrella"
        case .accepted: return "sparkles"
        case .expired: return "moon.zzz"
        }
    }
}

/// Global distribution rules. On the backend these live in configuration.
enum BottleRules {
    static let dailySendLimit = 10
    static let lifetime: TimeInterval = 72 * 60 * 60
    static let maxDeliveryAttempts = 12
    /// Don't deliver to the same recipient from the same sender within this window.
    static let recipientCooldown: TimeInterval = 7 * 24 * 60 * 60
    static let minimumAge = 18
}

/// An incoming bottle together with the limited sender info we're allowed to show.
struct IncomingBottle: Identifiable, Hashable {
    let message: BottleMessage
    let teaser: SenderTeaser
    let receivedAt: Date

    var id: UUID { message.id }
}

/// Deliberately minimal public information — the goal is curiosity.
struct SenderTeaser: Hashable {
    let senderID: UUID
    let nickname: String       // e.g. "M."
    let ageBracket: String     // e.g. "20s"
    let country: Country
    let city: String?          // only if the sender allows location visibility
    let languages: [String]
    let mood: String
    let avatarSeed: Int

    init(profile: UserProfile, showsLocation: Bool) {
        senderID = profile.id
        nickname = String(profile.firstName.prefix(1)) + "."
        ageBracket = profile.ageBracket
        country = profile.country
        city = showsLocation && !profile.city.isEmpty ? profile.city : nil
        languages = Array(profile.languages.prefix(3))
        mood = profile.status
        avatarSeed = profile.avatarSeed
    }

    var ref: UserRef { UserRef(id: senderID, name: "\(nickname) from \(country.name)", avatarSeed: avatarSeed) }
}

struct DailyQuota: Hashable {
    var sentToday: Int
    var limit: Int
    var remaining: Int { max(0, limit - sentToday) }
    var progress: Double { limit == 0 ? 1 : Double(sentToday) / Double(limit) }
}

/// Events pushed from the distribution backend (e.g. via WebSocket / push).
enum BottleEvent {
    case incoming(IncomingBottle)
    case found(bottleID: UUID, by: UserProfile, firstReply: String)
    case expired(bottleID: UUID)
}
