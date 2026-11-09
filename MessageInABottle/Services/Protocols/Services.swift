import Foundation

// All features talk to the backend exclusively through these protocols.
// `Mock*` implementations live in Services/Mock; production implementations
// (REST + WebSocket, Firebase, Supabase …) can be dropped in via `ServiceContainer`.

enum ServiceError: LocalizedError {
    case dailyLimitReached
    case moderationRejected(String)
    case notAllowed(String)
    case network
    case underage

    var errorDescription: String? {
        switch self {
        case .dailyLimitReached: return "You've used all your bottles for today. New ones arrive at midnight."
        case .moderationRejected(let reason): return reason
        case .notAllowed(let reason): return reason
        case .network: return "The sea is rough right now. Please try again."
        case .underage: return "You must be at least 18 to use Message in a Bottle."
        }
    }
}

// MARK: - Auth

@MainActor
protocol AuthServicing {
    func restoreSession() async -> UserProfile?
    func signUp(profile: UserProfile) async throws -> UserProfile
    func signInDemo() async throws -> UserProfile
    func signOut() async
    func deleteAccount(userID: UUID) async throws
}

// MARK: - Profile

@MainActor
protocol ProfileServicing {
    func save(_ profile: UserProfile) async throws -> UserProfile
    func loadSettings() async -> AppSettings
    func saveSettings(_ settings: AppSettings) async
}

// MARK: - Random distribution

/// Server-side responsibilities (see BACKEND.md):
/// eligibility, randomness, limits, blocking, expiration, re-queueing on skip.
@MainActor
protocol BottleDistributing {
    func quota(for userID: UUID) async -> DailyQuota
    func send(_ draft: BottleDraft, from sender: UserProfile) async throws -> BottleMessage
    func sentBottles(for userID: UUID) async -> [BottleMessage]
    /// Ask the server whether a bottle is waiting for this user.
    func checkShore(for user: UserProfile, settings: PrivacySettings) async -> IncomingBottle?
    /// Accepting creates a conversation with the sender.
    func accept(_ bottle: IncomingBottle, by user: UserProfile) async throws -> Conversation
    /// Skipping returns the bottle to the delivery pool for another eligible user.
    func skip(_ bottle: IncomingBottle, by user: UserProfile) async
    func events() -> AsyncStream<BottleEvent>
}

// MARK: - Discovery

@MainActor
protocol DiscoveryServicing {
    func candidates(for user: UserProfile, filters: DiscoveryFilters, preferences: DiscoveryPreferences) async -> [UserProfile]
    /// Returns `true` when interest is mutual.
    func like(_ profile: UserProfile, by user: UserProfile) async -> Bool
    func pass(_ profile: UserProfile, by user: UserProfile) async
    func sendConnectionRequest(to profile: UserProfile, from user: UserProfile, note: String?) async throws -> ConnectionRequest
    func incomingRequests(for user: UserProfile) async -> [ConnectionRequest]
    func respond(to request: ConnectionRequest, accept: Bool) async -> Conversation?
    func events() -> AsyncStream<DiscoveryEvent>
}

// MARK: - Messaging

@MainActor
protocol ChatServicing {
    func conversations(for user: UserProfile) async -> [Conversation]
    func send(_ message: ChatMessage, in conversation: Conversation, from user: UserProfile) async throws -> ChatMessage
    func update(_ message: ChatMessage, in conversation: Conversation) async
    func reveal(_ category: ProfileCategory, in conversation: Conversation, from user: UserProfile) async
    func markRead(_ conversation: Conversation) async
    func events() -> AsyncStream<ChatEvent>
}

// MARK: - Media

@MainActor
protocol MediaUploading {
    /// Uploads media and returns the item pointing at its remote location.
    func upload(_ item: MediaItem) async throws -> MediaItem
}

// MARK: - Safety

enum ModerationResult: Equatable {
    case allowed
    case rejected(reason: String)
}

@MainActor
protocol ModerationServicing {
    func review(text: String) -> ModerationResult
    func review(media: MediaItem) async -> ModerationResult
    func block(_ userID: UUID) async
    func unblock(_ userID: UUID) async
    func report(_ report: UserReport) async
}

// MARK: - Container

/// Single place to swap mocks for real implementations.
struct ServiceContainer {
    let auth: AuthServicing
    let profile: ProfileServicing
    let bottles: BottleDistributing
    let discovery: DiscoveryServicing
    let chat: ChatServicing
    let media: MediaUploading
    let moderation: ModerationServicing

    @MainActor
    static func mock() -> ServiceContainer {
        let db = MockDatabase.shared
        let moderation = MockModerationService(db: db)
        return ServiceContainer(
            auth: MockAuthService(db: db),
            profile: MockProfileService(),
            bottles: MockBottleService(db: db, moderation: moderation),
            discovery: MockDiscoveryService(db: db),
            chat: MockChatService(db: db),
            media: MockMediaService(),
            moderation: moderation
        )
    }
}
