import SwiftUI
import Observation

enum AppTab: String, CaseIterable, Identifiable {
    case bottle, explore, chats, profile
    var id: String { rawValue }

    var title: String {
        switch self {
        case .bottle: return "Bottle"
        case .explore: return "Explore"
        case .chats: return "Chats"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .bottle: return "waterbottle"
        case .explore: return "safari"
        case .chats: return "bubble.left.and.bubble.right"
        case .profile: return "person.crop.circle"
        }
    }
}

struct Toast: Identifiable, Equatable {
    enum Style { case info, success, warning, error }
    let id = UUID()
    let message: String
    var icon: String = "info.circle"
    var style: Style = .info
}

/// Single source of truth for app-wide state. Feature view models read and
/// mutate state through it; all backend access goes through `services`.
@MainActor
@Observable
final class AppModel {
    enum SessionState { case launching, signedOut, signedIn }

    let services: ServiceContainer

    // Session
    var session: SessionState = .launching
    var currentUser: UserProfile = MockData.demoUser()
    var settings = AppSettings()

    // Navigation
    var selectedTab: AppTab = .bottle
    var chatPath: [UUID] = []
    /// Tabs currently showing a pushed screen that hides the tab bar.
    var tabBarHiddenIn: Set<AppTab> = []
    var isTabBarHidden: Bool { tabBarHiddenIn.contains(selectedTab) }

    func setTabBar(hidden: Bool, for tab: AppTab) {
        if hidden { tabBarHiddenIn.insert(tab) } else { tabBarHiddenIn.remove(tab) }
    }

    // Bottle
    var quota = DailyQuota(sentToday: 0, limit: BottleRules.dailySendLimit)
    var sentBottles: [BottleMessage] = []
    var shore: [IncomingBottle] = []
    var presentedBottle: IncomingBottle?
    var arrivalBanner: IncomingBottle?

    // Social
    var conversations: [Conversation] = []
    var incomingRequests: [ConnectionRequest] = []
    var outgoingRequests: [UUID: ConnectionRequest] = [:]
    var blockedUsers: [UserRef] = []
    var reports: [UserReport] = []

    // Feedback
    var toast: Toast?

    @ObservationIgnored private var listeners: [Task<Void, Never>] = []
    @ObservationIgnored private var shoreTask: Task<Void, Never>?

    init(services: ServiceContainer) {
        self.services = services
    }

    // MARK: - Derived

    var unreadCount: Int { conversations.reduce(0) { $0 + $1.unreadCount } + incomingRequests.count }

    var sortedConversations: [Conversation] {
        conversations.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.lastActivity > $1.lastActivity
        }
    }

    func conversation(_ id: UUID) -> Conversation? {
        conversations.first { $0.id == id }
    }

    func isBlocked(_ id: UUID) -> Bool { blockedUsers.contains { $0.id == id } }

    // MARK: - Lifecycle

    func bootstrap() async {
        settings = await services.profile.loadSettings()
        if let user = await services.auth.restoreSession() {
            await enterApp(as: user)
        } else {
            withAnimation(Theme.Motion.gentle) { session = .signedOut }
        }
    }

    func signInDemo() async {
        do {
            let user = try await services.auth.signInDemo()
            await enterApp(as: user)
        } catch {
            show(error)
        }
    }

    func completeOnboarding(with profile: UserProfile) async throws {
        let user = try await services.auth.signUp(profile: profile)
        await enterApp(as: user)
    }

    private func enterApp(as user: UserProfile) async {
        currentUser = user
        startListening()
        conversations = await services.chat.conversations(for: user)
        incomingRequests = await services.discovery.incomingRequests(for: user)
        await refreshBottles()
        withAnimation(Theme.Motion.gentle) { session = .signedIn }
        startShorePolling()
    }

    func signOut() async {
        stopAll()
        await services.auth.signOut()
        resetState()
        withAnimation(Theme.Motion.gentle) { session = .signedOut }
    }

    func deleteAccount() async {
        do {
            stopAll()
            try await services.auth.deleteAccount(userID: currentUser.id)
            resetState()
            settings = AppSettings()
            withAnimation(Theme.Motion.gentle) { session = .signedOut }
            showToast("Your account and data were deleted.", icon: "trash", style: .info)
        } catch {
            show(error)
        }
    }

    private func resetState() {
        conversations = []
        incomingRequests = []
        outgoingRequests = [:]
        shore = []
        sentBottles = []
        chatPath = []
        selectedTab = .bottle
        presentedBottle = nil
        arrivalBanner = nil
        tabBarHiddenIn = []
        blockedUsers = []
        reports = []
    }

    private func stopAll() {
        listeners.forEach { $0.cancel() }
        listeners = []
        shoreTask?.cancel()
        shoreTask = nil
    }

    private func startListening() {
        guard listeners.isEmpty else { return }
        let chatEvents = services.chat.events()
        let bottleEvents = services.bottles.events()
        let discoveryEvents = services.discovery.events()

        listeners.append(Task { [weak self] in
            for await event in chatEvents { self?.handle(event) }
        })
        listeners.append(Task { [weak self] in
            for await event in bottleEvents { self?.handle(event) }
        })
        listeners.append(Task { [weak self] in
            for await event in discoveryEvents { self?.handle(event) }
        })
    }

    /// Simulates push notifications for bottles washing ashore.
    private func startShorePolling() {
        shoreTask?.cancel()
        shoreTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await self?.checkShore(silent: true)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 35...60) * 1_000_000_000))
                guard let self, !Task.isCancelled else { return }
                if self.shore.count < 3 { await self.checkShore(silent: true) }
            }
        }
    }

    // MARK: - Settings & profile

    func updateSettings(_ change: (inout AppSettings) -> Void) {
        change(&settings)
        let snapshot = settings
        Task { await services.profile.saveSettings(snapshot) }
    }

    func saveProfile(_ profile: UserProfile) async throws {
        if case .rejected(let reason) = services.moderation.review(text: profile.bio + " " + profile.status) {
            throw ServiceError.moderationRejected(reason)
        }
        currentUser = try await services.profile.save(profile)
        showToast("Profile saved", icon: "checkmark.circle", style: .success)
    }

    // MARK: - Bottles

    func refreshBottles() async {
        quota = await services.bottles.quota(for: currentUser.id)
        sentBottles = await services.bottles.sentBottles(for: currentUser.id)
    }

    func sendBottle(_ draft: BottleDraft) async throws {
        var uploaded: [MediaItem] = []
        for item in draft.media {
            uploaded.append(try await services.media.upload(item))
        }
        var finalDraft = draft
        finalDraft.media = uploaded
        _ = try await services.bottles.send(finalDraft, from: currentUser)
        await refreshBottles()
    }

    func checkShore(silent: Bool = false) async {
        guard settings.privacy.receiveBottles else {
            if !silent { showToast("Receiving bottles is turned off in Privacy settings.", icon: "hand.raised") }
            return
        }
        if let bottle = await services.bottles.checkShore(for: currentUser, settings: settings.privacy) {
            withAnimation(Theme.Motion.bouncy) {
                shore.append(bottle)
                arrivalBanner = bottle
            }
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 4_500_000_000)
                guard let self, self.arrivalBanner?.id == bottle.id else { return }
                withAnimation(Theme.Motion.snappy) { self.arrivalBanner = nil }
            }
        } else if !silent {
            showToast("The shore is quiet right now. Try again later.", icon: "water.waves")
        }
    }

    func open(_ bottle: IncomingBottle) {
        arrivalBanner = nil
        presentedBottle = bottle
    }

    func accept(_ bottle: IncomingBottle) async {
        do {
            let convo = try await services.bottles.accept(bottle, by: currentUser)
            withAnimation(Theme.Motion.snappy) {
                shore.removeAll { $0.id == bottle.id }
                conversations.append(convo)
            }
            presentedBottle = nil
            try? await Task.sleep(nanoseconds: 350_000_000)
            openConversation(convo.id)
        } catch {
            show(error)
        }
    }

    func skip(_ bottle: IncomingBottle) async {
        await services.bottles.skip(bottle, by: currentUser)
        withAnimation(Theme.Motion.snappy) { shore.removeAll { $0.id == bottle.id } }
        presentedBottle = nil
        showToast("The bottle drifted back to sea for someone else.", icon: "water.waves")
    }

    // MARK: - Navigation

    func openConversation(_ id: UUID) {
        selectedTab = .chats
        chatPath = [id]
    }

    // MARK: - Discovery & requests

    func sendConnectionRequest(to profile: UserProfile, note: String?) async {
        do {
            let request = try await services.discovery.sendConnectionRequest(to: profile, from: currentUser, note: note)
            outgoingRequests[profile.id] = request
            showToast("Request sent to \(profile.firstName)", icon: "paperplane", style: .success)
        } catch {
            show(error)
        }
    }

    func respond(to request: ConnectionRequest, accept: Bool) async {
        let convo = await services.discovery.respond(to: request, accept: accept)
        withAnimation(Theme.Motion.snappy) {
            incomingRequests.removeAll { $0.id == request.id }
            if let convo { conversations.append(convo) }
        }
        if let convo { openConversation(convo.id) }
    }

    func startConversationFromMatch(with profile: UserProfile) {
        if let existing = conversations.first(where: { $0.participant.id == profile.id }) {
            openConversation(existing.id)
            return
        }
        let convo = Conversation(participant: profile, origin: .match, messages: [
            ChatMessage(sender: .system, content: .system("You and \(profile.firstName) are connected. Break the ice 🧊"))
        ])
        conversations.append(convo)
        openConversation(convo.id)
    }

    // MARK: - Safety

    func block(_ user: UserRef) async {
        await services.moderation.block(user.id)
        withAnimation {
            if !blockedUsers.contains(where: { $0.id == user.id }) { blockedUsers.append(user) }
            conversations.removeAll { $0.participant.id == user.id }
            shore.removeAll { $0.teaser.senderID == user.id }
            incomingRequests.removeAll { $0.profile.id == user.id }
            chatPath = []
        }
        showToast("\(user.name) is blocked and can't contact you anymore.", icon: "hand.raised.fill")
    }

    func unblock(_ user: UserRef) async {
        await services.moderation.unblock(user.id)
        withAnimation { blockedUsers.removeAll { $0.id == user.id } }
        showToast("\(user.name) was unblocked", icon: "hand.thumbsup")
    }

    func report(_ user: UserRef, reason: ReportReason, details: String, alsoBlock: Bool) async {
        let report = UserReport(id: UUID(), user: user, reason: reason, details: details, createdAt: .now)
        await services.moderation.report(report)
        reports.insert(report, at: 0)
        if alsoBlock { await block(user) }
        showToast("Thanks — our safety team will review this report.", icon: "checkmark.shield", style: .success)
    }

    // MARK: - Messaging

    private func index(of conversationID: UUID) -> Int? {
        conversations.firstIndex { $0.id == conversationID }
    }

    func markRead(_ conversationID: UUID) {
        guard let i = index(of: conversationID) else { return }
        conversations[i].unreadCount = 0
        let convo = conversations[i]
        Task { await services.chat.markRead(convo) }
    }

    func send(_ content: ChatMessage.Content, in conversationID: UUID) async {
        if case .text(let text) = content,
           case .rejected(let reason) = services.moderation.review(text: text) {
            showToast(reason, icon: "exclamationmark.shield", style: .warning)
            return
        }
        guard let i = index(of: conversationID) else { return }
        var finalContent = content
        if case .media(let item, let caption) = content {
            if case .rejected(let reason) = await services.moderation.review(media: item) {
                showToast(reason, icon: "exclamationmark.shield", style: .warning)
                return
            }
            if let uploaded = try? await services.media.upload(item) {
                finalContent = .media(uploaded, caption: caption)
            }
        }
        let message = ChatMessage(sender: .me, content: finalContent, delivery: .sending)
        withAnimation(Theme.Motion.snappy) { conversations[i].messages.append(message) }
        await deliver(message, in: conversationID)
    }

    private func deliver(_ message: ChatMessage, in conversationID: UUID) async {
        guard let convo = conversation(conversationID) else { return }
        do {
            let sent = try await services.chat.send(message, in: convo, from: currentUser)
            replace(sent, in: conversationID)
        } catch {
            var failed = message
            failed.delivery = .failed
            replace(failed, in: conversationID)
        }
    }

    func updateMessage(_ message: ChatMessage, in conversationID: UUID) async {
        replace(message, in: conversationID)
        guard let convo = conversation(conversationID) else { return }
        await services.chat.update(message, in: convo)
    }

    func resolvePrompt(_ messageID: UUID, in conversationID: UUID) {
        guard let i = index(of: conversationID),
              let m = conversations[i].messages.firstIndex(where: { $0.id == messageID }) else { return }
        withAnimation { conversations[i].messages[m].isResolved = true }
    }

    /// Voluntary reveal — only ever triggered by an explicit user action.
    func reveal(_ category: ProfileCategory, in conversationID: UUID) async {
        guard let i = index(of: conversationID) else { return }
        guard currentUser.visibility(of: category) != .hidden else {
            showToast("\(category.title) is hidden in your profile settings.", icon: "eye.slash")
            return
        }
        guard !conversations[i].myRevealed.contains(category) else { return }
        let media = category == .media ? Array(currentUser.photos.prefix(4)) + currentUser.videos : []
        let message = ChatMessage(sender: .me, content: .reveal(category, items: currentUser.items(for: category), media: media))
        withAnimation(Theme.Motion.bouncy) {
            // Sharing answers any open invitation about this category.
            for m in conversations[i].messages.indices where !conversations[i].messages[m].isResolved {
                switch conversations[i].messages[m].content {
                case .reveal(let c, _, _) where c == category && conversations[i].messages[m].sender == .them:
                    conversations[i].messages[m].isResolved = true
                case .revealRequest(let c) where c == category && conversations[i].messages[m].sender == .them:
                    conversations[i].messages[m].isResolved = true
                default:
                    break
                }
            }
            conversations[i].messages.append(message)
            conversations[i].myRevealed.insert(category)
        }
        appendMutualIfNeeded(category, at: i)
        let convo = conversations[i]
        await services.chat.reveal(category, in: convo, from: currentUser)
    }

    func requestReveal(_ category: ProfileCategory, in conversationID: UUID) async {
        await send(.revealRequest(category), in: conversationID)
    }

    private func appendMutualIfNeeded(_ category: ProfileCategory, at i: Int) {
        let convo = conversations[i]
        guard convo.myRevealed.contains(category), convo.theirRevealed.contains(category) else { return }
        let alreadyShown = convo.messages.contains {
            if case .mutualReveal(let c) = $0.content { return c == category }
            return false
        }
        guard !alreadyShown else { return }
        withAnimation(Theme.Motion.bouncy) {
            conversations[i].messages.append(ChatMessage(sender: .system, content: .mutualReveal(category)))
        }
    }

    private func replace(_ message: ChatMessage, in conversationID: UUID) {
        guard let i = index(of: conversationID),
              let m = conversations[i].messages.firstIndex(where: { $0.id == message.id }) else { return }
        conversations[i].messages[m] = message
    }

    // MARK: - Event handling

    private func handle(_ event: ChatEvent) {
        switch event {
        case .typing(let id, let isTyping):
            guard let i = index(of: id) else { return }
            withAnimation(Theme.Motion.snappy) { conversations[i].isTyping = isTyping }
        case .message(let id, let message):
            guard let i = index(of: id) else { return }
            withAnimation(Theme.Motion.snappy) {
                conversations[i].messages.append(message)
                if chatPath.last != id || selectedTab != .chats { conversations[i].unreadCount += 1 }
            }
            if case .reveal(let category, _, _) = message.content, message.sender == .them {
                conversations[i].theirRevealed.insert(category)
                appendMutualIfNeeded(category, at: i)
            }
        case .update(let id, let message):
            withAnimation(Theme.Motion.snappy) { replace(message, in: id) }
        case .revealed(let id, let category):
            guard let i = index(of: id) else { return }
            conversations[i].theirRevealed.insert(category)
            appendMutualIfNeeded(category, at: i)
        case .newConversation(let convo):
            conversations.append(convo)
        }
    }

    private func handle(_ event: BottleEvent) {
        switch event {
        case .incoming(let bottle):
            withAnimation(Theme.Motion.bouncy) {
                shore.append(bottle)
                arrivalBanner = bottle
            }
        case .found(let bottleID, let finder, let reply):
            Task { await refreshBottles() }
            guard !isBlocked(finder.id) else { return }
            let original = sentBottles.first { $0.id == bottleID }
            var messages: [ChatMessage] = []
            if let original {
                messages.append(ChatMessage(sender: .me, sentAt: original.createdAt,
                                            content: .bottle(text: original.text, media: original.media), delivery: .read))
            }
            messages.append(ChatMessage(sender: .system, content: .system("Your bottle washed ashore in \(finder.country.flag) \(finder.country.name)")))
            messages.append(ChatMessage(sender: .them, content: .text(reply)))
            let convo = Conversation(participant: finder, origin: .bottle, messages: messages, unreadCount: 1)
            withAnimation(Theme.Motion.snappy) { conversations.append(convo) }
            if settings.notifications.bottleFound {
                showToast("Your bottle was found in \(finder.country.flag) \(finder.country.name)!", icon: "sparkles", style: .success)
            }
        case .expired:
            Task { await refreshBottles() }
        }
    }

    private func handle(_ event: DiscoveryEvent) {
        switch event {
        case .requestAccepted(let request, let convo):
            outgoingRequests[request.profile.id] = request
            guard !isBlocked(request.profile.id) else { return }
            withAnimation(Theme.Motion.snappy) { conversations.append(convo) }
            if settings.notifications.connectionRequests {
                showToast("\(request.profile.firstName) accepted your request 🎉", icon: "person.crop.circle.badge.checkmark", style: .success)
            }
        case .incomingRequest(let request):
            withAnimation { incomingRequests.append(request) }
        }
    }

    // MARK: - Feedback

    func showToast(_ message: String, icon: String = "info.circle", style: Toast.Style = .info) {
        let toast = Toast(message: message, icon: icon, style: style)
        withAnimation(Theme.Motion.snappy) { self.toast = toast }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, self.toast?.id == toast.id else { return }
            withAnimation(Theme.Motion.snappy) { self.toast = nil }
        }
    }

    func show(_ error: Error) {
        showToast(error.localizedDescription, icon: "exclamationmark.triangle", style: .error)
    }
}
