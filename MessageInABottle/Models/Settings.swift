import Foundation

enum Audience: String, CaseIterable, Identifiable, Codable {
    case everyone, sharedInterests, connections, nobody
    var id: String { rawValue }

    var title: String {
        switch self {
        case .everyone: return "Everyone"
        case .sharedInterests: return "People with shared interests"
        case .connections: return "Connections only"
        case .nobody: return "Nobody"
        }
    }
}

struct PrivacySettings: Hashable, Codable {
    var connectionRequestsFrom: Audience = .everyone
    var profileVisibleTo: Audience = .everyone
    var dailyIncomingLimit: Int = 20
    var appearInDiscovery: Bool = true
    var showLocation: Bool = true
    var showOnlineStatus: Bool = true
    var receiveBottles: Bool = true

    static let incomingLimitOptions = [5, 20, 50, 100]
}

struct DiscoveryPreferences: Hashable, Codable {
    var minAge: Int = 18
    var maxAge: Int = 45
    var preferredLanguages: [String] = []
    var bottlesFromAnywhere: Bool = true
}

struct NotificationSettings: Hashable, Codable {
    var newBottles = true
    var messages = true
    var connectionRequests = true
    var gameInvites = true
    var bottleFound = true
}

enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case english = "English", russian = "Русский", kyrgyz = "Кыргызча", turkish = "Türkçe", spanish = "Español"
    var id: String { rawValue }
}

struct AppSettings: Hashable, Codable {
    var privacy = PrivacySettings()
    var discovery = DiscoveryPreferences()
    var notifications = NotificationSettings()
    var theme: AppTheme = .system
    var language: AppLanguage = .english
}

/// Explore filters (session-level, not persisted).
struct DiscoveryFilters: Hashable {
    var minAge: Int = 18
    var maxAge: Int = 60
    var country: Country? = nil
    var city: String = ""
    var languages: Set<String> = []
    var interests: Set<String> = []
    var hobbies: Set<String> = []
    var onlineOnly: Bool = false

    var activeCount: Int {
        var n = 0
        if minAge != 18 || maxAge != 60 { n += 1 }
        if country != nil { n += 1 }
        if !city.trimmingCharacters(in: .whitespaces).isEmpty { n += 1 }
        if !languages.isEmpty { n += 1 }
        if !interests.isEmpty { n += 1 }
        if !hobbies.isEmpty { n += 1 }
        if onlineOnly { n += 1 }
        return n
    }
}

enum ReportReason: String, CaseIterable, Identifiable, Hashable {
    case spam = "Spam or scam"
    case harassment = "Harassment or bullying"
    case inappropriate = "Inappropriate content"
    case underage = "May be under 18"
    case impersonation = "Fake profile / impersonation"
    case other = "Something else"
    var id: String { rawValue }
}

/// Lightweight reference to another user (for safety lists and reports).
struct UserRef: Identifiable, Hashable {
    let id: UUID
    let name: String
    let avatarSeed: Int
    var avatar: MediaItem? = nil
}

struct UserReport: Identifiable, Hashable {
    let id: UUID
    let user: UserRef
    let reason: ReportReason
    let details: String
    let createdAt: Date
}
