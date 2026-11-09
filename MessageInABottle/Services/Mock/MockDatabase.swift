import Foundation

/// In-memory stand-in for the backend database.
/// The eligibility logic here mirrors what the server must do (see BACKEND.md).
@MainActor
final class MockDatabase {
    static let shared = MockDatabase()

    private(set) var community: [UserProfile]
    /// Privacy settings of other users (the recipient side of distribution).
    private var privacy: [UUID: PrivacySettings] = [:]
    private var receivedToday: [UUID: Int] = [:]
    /// sender -> recipient -> last delivery date
    private var deliveryLog: [UUID: [UUID: Date]] = [:]
    private(set) var blocked: Set<UUID> = []
    /// Users who already "liked" the current user (to simulate mutual matches).
    private(set) var admirers: Set<UUID> = []

    /// Bottles written by the community, waiting to wash ashore.
    var pool: [BottleMessage] = []
    /// Bottles written by the current user.
    var sentBottles: [BottleMessage] = []

    private init() {
        community = MockData.community()
        for user in community {
            var p = PrivacySettings()
            p.dailyIncomingLimit = [20, 50, 100].randomElement() ?? 20
            p.showLocation = Bool.random() || Bool.random()
            privacy[user.id] = p
            if Double.random(in: 0...1) < 0.45 { admirers.insert(user.id) }
        }
        seedPool()
    }

    func profile(_ id: UUID) -> UserProfile? {
        community.first { $0.id == id }
    }

    func privacySettings(for id: UUID) -> PrivacySettings {
        privacy[id] ?? PrivacySettings()
    }

    private func seedPool() {
        let texts = MockData.bottleTexts.shuffled()
        for (index, sender) in community.shuffled().enumerated() {
            var media: [MediaItem] = []
            if index % 3 == 0 { media.append(.remotePhoto("bottle-\(index)", w: 900, h: 700)) }
            if index == 4 { media.append(.sampleVideo(posterSeed: "bottle-video")) }
            let bottle = BottleMessage(
                senderID: sender.id,
                text: texts[index % texts.count],
                media: media,
                createdAt: Date.now.addingTimeInterval(-Double.random(in: 600...40_000))
            )
            pool.append(bottle)
        }
    }

    // MARK: Safety

    func block(_ id: UUID) { blocked.insert(id) }
    func unblock(_ id: UUID) { blocked.remove(id) }
    func isBlocked(_ id: UUID) -> Bool { blocked.contains(id) }

    // MARK: Distribution — recipient selection (server logic)

    /// Picks a random eligible recipient for a bottle. Mirrors the backend rules:
    /// not the sender, adult, not blocked either way, accepts bottles, below their
    /// daily receiving limit, hasn't skipped this bottle, not recently picked by
    /// this sender — then prefers the least-loaded half for fairness.
    func pickRecipient(for bottle: BottleMessage, sender: UserProfile) -> UserProfile? {
        let now = Date.now
        let eligible = community.filter { candidate in
            guard candidate.id != sender.id, candidate.isAdult else { return false }
            guard !blocked.contains(candidate.id) else { return false }
            guard !bottle.skippedBy.contains(candidate.id) else { return false }
            let settings = privacySettings(for: candidate.id)
            guard settings.receiveBottles else { return false }
            guard (receivedToday[candidate.id] ?? 0) < settings.dailyIncomingLimit else { return false }
            if let last = deliveryLog[sender.id]?[candidate.id],
               now.timeIntervalSince(last) < BottleRules.recipientCooldown { return false }
            return true
        }
        guard !eligible.isEmpty else { return nil }
        let sorted = eligible.sorted { (receivedToday[$0.id] ?? 0) < (receivedToday[$1.id] ?? 0) }
        let fairHalf = sorted.prefix(max(1, sorted.count / 2))
        guard let chosen = fairHalf.randomElement() else { return nil }
        receivedToday[chosen.id, default: 0] += 1
        deliveryLog[sender.id, default: [:]][chosen.id] = now
        return chosen
    }

    /// Finds a bottle for the current user (the user is the candidate recipient).
    func nextBottle(for user: UserProfile, settings: PrivacySettings, receivedToday count: Int) -> BottleMessage? {
        guard settings.receiveBottles, count < settings.dailyIncomingLimit, user.isAdult else { return nil }
        purgeExpired()
        let candidates = pool.indices.filter { i in
            let b = pool[i]
            return b.status == .drifting
                && b.senderID != user.id
                && !b.skippedBy.contains(user.id)
                && !blocked.contains(b.senderID)
                && (profile(b.senderID)?.isAdult ?? false)
        }
        guard let index = candidates.randomElement() else { return nil }
        pool[index].status = .delivered
        pool[index].currentRecipientID = user.id
        pool[index].deliveryAttempts += 1
        return pool[index]
    }

    /// Skip → back into the pool for another eligible user.
    func returnToPool(_ bottleID: UUID, skippedBy userID: UUID) {
        guard let i = pool.firstIndex(where: { $0.id == bottleID }) else { return }
        pool[i].skippedBy.insert(userID)
        pool[i].currentRecipientID = nil
        pool[i].status = pool[i].isExpired ? .expired : .drifting
    }

    func markAccepted(_ bottleID: UUID) {
        guard let i = pool.firstIndex(where: { $0.id == bottleID }) else { return }
        pool[i].status = .accepted
    }

    func purgeExpired() {
        for i in pool.indices where pool[i].isExpired && pool[i].status == .drifting {
            pool[i].status = .expired
        }
        for i in sentBottles.indices where sentBottles[i].isExpired && sentBottles[i].status == .drifting {
            sentBottles[i].status = .expired
        }
        // Keep the mock ocean from running dry.
        if pool.filter({ $0.status == .drifting }).count < 3 {
            refillPool()
        }
    }

    private func refillPool() {
        for sender in community.shuffled().prefix(5) where !blocked.contains(sender.id) {
            pool.append(BottleMessage(senderID: sender.id,
                                      text: MockData.bottleTexts.randomElement() ?? "Hello!",
                                      media: []))
        }
    }

    func isAdmirer(_ id: UUID) -> Bool { admirers.contains(id) }
}
