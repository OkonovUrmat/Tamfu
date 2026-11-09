import Foundation

/// Small async delay helper used by mocks to feel like a network.
func simulatedLatency(_ seconds: Double = 0.4) async {
    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
}

// MARK: - Local persistence

/// Tiny JSON-in-UserDefaults store for the signed-in profile and settings.
enum LocalStore {
    private static let profileKey = "mib.profile"
    private static let settingsKey = "mib.settings"
    private static let defaults = UserDefaults.standard

    static func saveProfile(_ profile: UserProfile?) {
        guard let profile else { defaults.removeObject(forKey: profileKey); return }
        // Strip raw image bytes to keep defaults small; they'd be uploaded in production.
        var copy = profile
        copy.photos = copy.photos.filter { if case .imageData = $0.source { return false }; return true }
        copy.videos = copy.videos.filter { if case .localFile = $0.source { return false }; return true }
        if let data = try? JSONEncoder().encode(copy) { defaults.set(data, forKey: profileKey) }
    }

    static func loadProfile() -> UserProfile? {
        guard let data = defaults.data(forKey: profileKey) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }

    static func saveSettings(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: settingsKey) }
    }

    static func loadSettings() -> AppSettings {
        guard let data = defaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else { return AppSettings() }
        return settings
    }

    static func todayKey(_ prefix: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "\(prefix).\(f.string(from: .now))"
    }

    static func counter(_ prefix: String) -> Int { defaults.integer(forKey: todayKey(prefix)) }
    static func increment(_ prefix: String) { defaults.set(counter(prefix) + 1, forKey: todayKey(prefix)) }

    static func wipe() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("mib.") {
            defaults.removeObject(forKey: key)
        }
    }
}

// MARK: - Auth

@MainActor
final class MockAuthService: AuthServicing {
    private let db: MockDatabase
    init(db: MockDatabase) { self.db = db }

    func restoreSession() async -> UserProfile? {
        LocalStore.loadProfile()
    }

    func signUp(profile: UserProfile) async throws -> UserProfile {
        await simulatedLatency(0.8)
        guard profile.age >= BottleRules.minimumAge else { throw ServiceError.underage }
        LocalStore.saveProfile(profile)
        return profile
    }

    func signInDemo() async throws -> UserProfile {
        await simulatedLatency(0.6)
        let user = MockData.demoUser()
        LocalStore.saveProfile(user)
        return user
    }

    func signOut() async {
        await simulatedLatency(0.3)
        LocalStore.saveProfile(nil)
    }

    func deleteAccount(userID: UUID) async throws {
        await simulatedLatency(1.0)
        LocalStore.wipe()
    }
}

// MARK: - Profile

@MainActor
final class MockProfileService: ProfileServicing {
    func save(_ profile: UserProfile) async throws -> UserProfile {
        await simulatedLatency(0.5)
        LocalStore.saveProfile(profile)
        return profile
    }

    func loadSettings() async -> AppSettings { LocalStore.loadSettings() }

    func saveSettings(_ settings: AppSettings) async { LocalStore.saveSettings(settings) }
}

// MARK: - Media

@MainActor
final class MockMediaService: MediaUploading {
    func upload(_ item: MediaItem) async throws -> MediaItem {
        await simulatedLatency(0.7)
        return item   // A real implementation returns a CDN URL.
    }
}

// MARK: - Moderation

@MainActor
final class MockModerationService: ModerationServicing {
    private let db: MockDatabase
    private(set) var reports: [UserReport] = []

    init(db: MockDatabase) { self.db = db }

    private let bannedWords = ["idiot", "stupid", "hate you", "kill", "nude", "nudes", "send money", "bitcoin", "onlyfans"]

    func review(text: String) -> ModerationResult {
        let lower = text.lowercased()
        if bannedWords.contains(where: { lower.contains($0) }) {
            return .rejected(reason: "Let's keep the ocean kind — this message looks like it breaks our community guidelines.")
        }
        let links = lower.components(separatedBy: "http").count - 1
        if links > 1 || lower.contains("t.me/") || lower.contains("wa.me/") {
            return .rejected(reason: "Links and contact handles aren't allowed in bottles. Get to know each other in the chat first.")
        }
        if lower.range(of: #"\+?\d[\d\s\-]{8,}\d"#, options: .regularExpression) != nil {
            return .rejected(reason: "For your safety, don't share phone numbers with strangers.")
        }
        // Spam heuristic: same character repeated / shouting.
        if lower.range(of: #"(.)\1{9,}"#, options: .regularExpression) != nil {
            return .rejected(reason: "This looks like spam. Try writing something personal.")
        }
        let letters = text.filter { $0.isLetter }
        if letters.count > 20, Double(letters.filter { $0.isUppercase }.count) / Double(letters.count) > 0.8 {
            return .rejected(reason: "No need to shout 🙂 Try lowercase.")
        }
        return .allowed
    }

    func review(media: MediaItem) async -> ModerationResult {
        // Production: server-side image/video classification (e.g. AWS Rekognition, Hive).
        await simulatedLatency(0.6)
        return .allowed
    }

    func block(_ userID: UUID) async { db.block(userID) }
    func unblock(_ userID: UUID) async { db.unblock(userID) }

    func report(_ report: UserReport) async {
        await simulatedLatency(0.4)
        reports.append(report)
    }
}

// MARK: - Bottles

@MainActor
final class MockBottleService: BottleDistributing {
    private let db: MockDatabase
    private let moderation: ModerationServicing
    private var continuation: AsyncStream<BottleEvent>.Continuation?

    init(db: MockDatabase, moderation: ModerationServicing) {
        self.db = db
        self.moderation = moderation
    }

    /// Each subscription gets a fresh stream (AsyncStream is single-consumer).
    func events() -> AsyncStream<BottleEvent> {
        continuation?.finish()
        return AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    func quota(for userID: UUID) async -> DailyQuota {
        DailyQuota(sentToday: LocalStore.counter("mib.sent"), limit: BottleRules.dailySendLimit)
    }

    func send(_ draft: BottleDraft, from sender: UserProfile) async throws -> BottleMessage {
        let quota = await self.quota(for: sender.id)
        guard quota.remaining > 0 else { throw ServiceError.dailyLimitReached }
        if case .rejected(let reason) = moderation.review(text: draft.trimmedText) {
            throw ServiceError.moderationRejected(reason)
        }
        for item in draft.media {
            if case .rejected(let reason) = await moderation.review(media: item) {
                throw ServiceError.moderationRejected(reason)
            }
        }
        await simulatedLatency(0.9)

        var bottle = BottleMessage(senderID: sender.id, text: draft.trimmedText, media: draft.media)
        let recipient = db.pickRecipient(for: bottle, sender: sender)
        bottle.currentRecipientID = recipient?.id
        bottle.status = recipient == nil ? .drifting : .delivered
        bottle.deliveryAttempts = recipient == nil ? 0 : 1
        db.sentBottles.insert(bottle, at: 0)
        LocalStore.increment("mib.sent")

        simulateFate(of: bottle.id, firstRecipient: recipient, sender: sender)
        return bottle
    }

    func sentBottles(for userID: UUID) async -> [BottleMessage] {
        db.purgeExpired()
        return db.sentBottles
    }

    func checkShore(for user: UserProfile, settings: PrivacySettings) async -> IncomingBottle? {
        await simulatedLatency(0.5)
        let received = LocalStore.counter("mib.received")
        guard let bottle = db.nextBottle(for: user, settings: settings, receivedToday: received),
              let sender = db.profile(bottle.senderID) else { return nil }
        LocalStore.increment("mib.received")
        let teaser = SenderTeaser(profile: sender, showsLocation: db.privacySettings(for: sender.id).showLocation)
        return IncomingBottle(message: bottle, teaser: teaser, receivedAt: .now)
    }

    func accept(_ bottle: IncomingBottle, by user: UserProfile) async throws -> Conversation {
        await simulatedLatency(0.5)
        guard let sender = db.profile(bottle.teaser.senderID) else { throw ServiceError.network }
        db.markAccepted(bottle.id)
        let opening = ChatMessage(sender: .them, sentAt: bottle.message.createdAt,
                                  content: .bottle(text: bottle.message.text, media: bottle.message.media))
        let note = ChatMessage(sender: .system, content: .system("You opened \(sender.firstName)'s bottle. Say hello 👋"))
        return Conversation(participant: sender, origin: .bottle, messages: [opening, note])
    }

    func skip(_ bottle: IncomingBottle, by user: UserProfile) async {
        await simulatedLatency(0.3)
        db.returnToPool(bottle.id, skippedBy: user.id)
    }

    /// Simulates what happens out at sea: a recipient may accept, or skip and the
    /// server re-delivers to someone else, until it's found or expires.
    private func simulateFate(of bottleID: UUID, firstRecipient: UserProfile?, sender: UserProfile) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            var recipient = firstRecipient
            for _ in 0..<3 {
                try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 7...14) * 1_000_000_000))
                guard let current = recipient,
                      let index = self.db.sentBottles.firstIndex(where: { $0.id == bottleID }) else { return }
                if Double.random(in: 0...1) < 0.6 {
                    self.db.sentBottles[index].status = .accepted
                    self.db.sentBottles[index].foundIn = current.country
                    let reply = ["Hi! Your bottle just washed up on my shore 🌊",
                                 "Wow, I never thought I'd get one of these. Hello from \(current.city)!",
                                 "I found your message and had to answer it 😊"].randomElement() ?? "Hi!"
                    self.continuation?.yield(.found(bottleID: bottleID, by: current, firstReply: reply))
                    return
                } else {
                    // Skipped → back to the pool, delivered to another eligible user.
                    self.db.sentBottles[index].skippedBy.insert(current.id)
                    self.db.sentBottles[index].deliveryAttempts += 1
                    let bottle = self.db.sentBottles[index]
                    recipient = bottle.isExpired ? nil : self.db.pickRecipient(for: bottle, sender: sender)
                    self.db.sentBottles[index].currentRecipientID = recipient?.id
                    self.db.sentBottles[index].status = recipient == nil ? .drifting : .delivered
                }
            }
        }
    }
}

// MARK: - Discovery

@MainActor
final class MockDiscoveryService: DiscoveryServicing {
    private let db: MockDatabase
    private var seen: Set<UUID> = []
    private var continuation: AsyncStream<DiscoveryEvent>.Continuation?
    private var didSeedRequests = false

    init(db: MockDatabase) { self.db = db }

    /// Each subscription gets a fresh stream (AsyncStream is single-consumer).
    func events() -> AsyncStream<DiscoveryEvent> {
        continuation?.finish()
        return AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    func candidates(for user: UserProfile, filters: DiscoveryFilters, preferences: DiscoveryPreferences) async -> [UserProfile] {
        await simulatedLatency(0.6)
        return db.community.filter { p in
            guard p.id != user.id, p.isAdult, !db.isBlocked(p.id), !seen.contains(p.id) else { return false }
            let privacy = db.privacySettings(for: p.id)
            guard privacy.appearInDiscovery, privacy.profileVisibleTo != .nobody else { return false }
            guard p.age >= filters.minAge, p.age <= filters.maxAge else { return false }
            if let c = filters.country, p.country != c { return false }
            let city = filters.city.trimmingCharacters(in: .whitespaces)
            if !city.isEmpty, !privacy.showLocation || !p.city.localizedCaseInsensitiveContains(city) { return false }
            if !filters.languages.isEmpty, filters.languages.isDisjoint(with: p.languages) { return false }
            if !filters.interests.isEmpty, filters.interests.isDisjoint(with: p.interests) { return false }
            if !filters.hobbies.isEmpty, filters.hobbies.isDisjoint(with: p.hobbies) { return false }
            if filters.onlineOnly, !p.isOnline { return false }
            return true
        }
        .map { profile in
            // Respect location visibility: never send a hidden city to clients.
            var copy = profile
            if !db.privacySettings(for: profile.id).showLocation { copy.city = "" }
            return copy
        }
        .shuffled()
    }

    func like(_ profile: UserProfile, by user: UserProfile) async -> Bool {
        seen.insert(profile.id)
        await simulatedLatency(0.2)
        return db.isAdmirer(profile.id)
    }

    func pass(_ profile: UserProfile, by user: UserProfile) async {
        seen.insert(profile.id)
    }

    func sendConnectionRequest(to profile: UserProfile, from user: UserProfile, note: String?) async throws -> ConnectionRequest {
        let privacy = db.privacySettings(for: profile.id)
        switch privacy.connectionRequestsFrom {
        case .nobody:
            throw ServiceError.notAllowed("\(profile.firstName) isn't accepting connection requests right now.")
        case .sharedInterests where Set(profile.interests).isDisjoint(with: user.interests):
            throw ServiceError.notAllowed("\(profile.firstName) only accepts requests from people with shared interests.")
        default: break
        }
        await simulatedLatency(0.6)
        let request = ConnectionRequest(profile: profile, direction: .outgoing, note: note)
        // Simulate the other person answering a bit later.
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 6...12) * 1_000_000_000))
            guard let self, !self.db.isBlocked(profile.id) else { return }
            var accepted = request
            accepted.state = .accepted
            let convo = Conversation(participant: profile, origin: .request, messages: [
                ChatMessage(sender: .system, content: .system("\(profile.firstName) accepted your connection request")),
                ChatMessage(sender: .them, content: .text("Hey! Thanks for reaching out 😊 \(note.map { _ in "Loved your note." } ?? "")"))
            ], unreadCount: 1)
            self.continuation?.yield(.requestAccepted(accepted, convo))
        }
        return request
    }

    func incomingRequests(for user: UserProfile) async -> [ConnectionRequest] {
        guard !didSeedRequests else { return [] }
        didSeedRequests = true
        await simulatedLatency(0.3)
        return db.community.suffix(2).map {
            ConnectionRequest(profile: $0, direction: .incoming,
                              note: "Your profile made me smile — want to swap stories?",
                              createdAt: Date.now.addingTimeInterval(-Double.random(in: 900...20_000)))
        }
    }

    func respond(to request: ConnectionRequest, accept: Bool) async -> Conversation? {
        await simulatedLatency(0.4)
        guard accept else { return nil }
        return Conversation(participant: request.profile, origin: .request, messages: [
            ChatMessage(sender: .system, content: .system("You're now connected with \(request.profile.firstName)")),
            ChatMessage(sender: .them, content: .text(request.note ?? "Hi there 👋"))
        ])
    }
}
