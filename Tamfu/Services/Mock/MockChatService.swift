import Foundation

/// Mock messaging backend. Emits real-time events through an AsyncStream the
/// same way a WebSocket client would, and simulates the other person so that
/// chats, reveals and games feel alive during development.
@MainActor
final class MockChatService: ChatServicing {
    private let db: MockDatabase
    private var continuation: AsyncStream<ChatEvent>.Continuation?
    private var replyCounter: [UUID: Int] = [:]

    init(db: MockDatabase) { self.db = db }

    /// Each subscription gets a fresh stream (AsyncStream is single-consumer).
    func events() -> AsyncStream<ChatEvent> {
        continuation?.finish()
        return AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    // MARK: Seed conversations

    func conversations(for user: UserProfile) async -> [Conversation] {
        await simulatedLatency(0.4)
        let people = db.community
        guard people.count >= 9 else { return [] }
        let maria = people[0], kenji = people[1], elif = people[8]
        let now = Date.now
        func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }

        let mariaChat = Conversation(
            participant: maria, origin: .bottle,
            messages: [
                ChatMessage(sender: .them, sentAt: ago(180),
                            content: .bottle(text: "I just watched the sunrise over the ocean for the first time. Sending you a little of it 🌅",
                                             media: [maria.photos[1]])),
                ChatMessage(sender: .system, sentAt: ago(179), content: .system("You opened Maria's bottle")),
                ChatMessage(sender: .me, sentAt: ago(170), content: .text("This is beautiful! Greetings from Bishkek 🏔️"), delivery: .read),
                ChatMessage(sender: .them, sentAt: ago(160), content: .text("Bishkek! I had to look it up on the map 😅 Mountains everywhere?")),
                ChatMessage(sender: .me, sentAt: ago(150), content: .text("Mountains everywhere. You'd love the lakes."), delivery: .read),
                ChatMessage(sender: .them, sentAt: ago(30),
                            content: .reveal(.hobbies, items: maria.hobbies, media: [])),
            ],
            theirRevealed: [.hobbies], unreadCount: 2, isPinned: true, createdAt: ago(180)
        )

        let question = GameSession(startedBy: .them, state: .question(QuestionRound(
            category: .travel,
            question: "Which city would you move to tomorrow if you could?",
            myAnswer: "Lisbon — the light there feels unreal.",
            theirAnswer: "Bishkek, apparently 😄 I keep hearing about the mountains.")))
        let kenjiChat = Conversation(
            participant: kenji, origin: .match,
            messages: [
                ChatMessage(sender: .system, sentAt: ago(1500), content: .system("You and Kenji are connected")),
                ChatMessage(sender: .them, sentAt: ago(1490), content: .text("Hello from Kyoto! Your film photos are great.")),
                ChatMessage(sender: .me, sentAt: ago(1480), content: .text("Thank you! Portra 400 forever."), delivery: .read),
                ChatMessage(sender: .them, sentAt: ago(1400), content: .game(question)),
                ChatMessage(sender: .me, sentAt: ago(1300), content: .reveal(.music, items: user.details.music, media: []), delivery: .read),
                ChatMessage(sender: .them, sentAt: ago(1290), content: .reveal(.music, items: kenji.details.music, media: [])),
                ChatMessage(sender: .system, sentAt: ago(1289), content: .mutualReveal(.music)),
                ChatMessage(sender: .them, sentAt: ago(1200), content: .media(kenji.photos[2], caption: "Today's walk"))
            ],
            myRevealed: [.music], theirRevealed: [.music], createdAt: ago(1500)
        )

        let elifChat = Conversation(
            participant: elif, origin: .request,
            messages: [
                ChatMessage(sender: .system, sentAt: ago(4000), content: .system("You're now connected with Elif")),
                ChatMessage(sender: .them, sentAt: ago(3990), content: .text("Merhaba! Have you ever been to Istanbul?")),
                ChatMessage(sender: .me, sentAt: ago(3900), content: .text("Not yet, it's on my list!"), delivery: .read),
                ChatMessage(sender: .them, sentAt: ago(3800), content: .revealRequest(.moviesBooks))
            ],
            createdAt: ago(4000)
        )
        return [mariaChat, kenjiChat, elifChat]
    }

    // MARK: Sending

    func send(_ message: ChatMessage, in conversation: Conversation, from user: UserProfile) async throws -> ChatMessage {
        await simulatedLatency(0.35)
        var sent = message
        sent.delivery = .sent
        scheduleResponse(to: sent, in: conversation)
        return sent
    }

    func update(_ message: ChatMessage, in conversation: Conversation) async {
        await simulatedLatency(0.2)
        if case .game(let session) = message.content {
            respondToGame(session, messageID: message.id, in: conversation)
        }
    }

    func reveal(_ category: ProfileCategory, in conversation: Conversation, from user: UserProfile) async {
        await simulatedLatency(0.3)
        respondToReveal(category, in: conversation)
    }

    func markRead(_ conversation: Conversation) async {}

    // MARK: Simulated partner

    private func emit(_ event: ChatEvent) { continuation?.yield(event) }

    private func pause(_ range: ClosedRange<Double>) async {
        try? await Task.sleep(nanoseconds: UInt64(Double.random(in: range) * 1_000_000_000))
    }

    private func typeThen(_ conversationID: UUID, _ seconds: ClosedRange<Double> = 1.2...2.6, _ action: @escaping @MainActor () -> Void) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.pause(0.6...1.2)
            guard !self.db.isBlocked(self.partnerID(conversationID)) else { return }
            self.emit(.typing(conversationID: conversationID, isTyping: true))
            await self.pause(seconds)
            self.emit(.typing(conversationID: conversationID, isTyping: false))
            action()
        }
    }

    private var partners: [UUID: UUID] = [:]
    private func partnerID(_ conversationID: UUID) -> UUID { partners[conversationID] ?? UUID() }

    private func scheduleResponse(to message: ChatMessage, in conversation: Conversation) {
        partners[conversation.id] = conversation.participant.id
        let partner = conversation.participant
        let id = conversation.id

        switch message.content {
        case .revealRequest(let category):
            typeThen(id) { [weak self] in
                guard let self else { return }
                if partner.visibility(of: category) != .hidden, partner.hasContent(for: category) {
                    self.emit(.message(conversationID: id, ChatMessage(sender: .them, content: .text("Sure, why not 🙂"))))
                    self.emitReveal(category, of: partner, in: id)
                } else {
                    self.emit(.message(conversationID: id, ChatMessage(sender: .them, content: .text("I keep that one private for now 🙈 Ask me something else?"))))
                }
            }
        case .game(let session):
            respondToGame(session, messageID: message.id, in: conversation)
        case .text, .media:
            let count = (replyCounter[id] ?? 0) + 1
            replyCounter[id] = count
            typeThen(id) { [weak self] in
                guard let self else { return }
                let text: String
                if case .media = message.content {
                    text = ["Wow, nice shot 📸", "Okay that's beautiful", "Is that where you live?!"].randomElement() ?? "Nice!"
                } else {
                    text = MockData.partnerReplies.randomElement() ?? "😊"
                }
                self.emit(.message(conversationID: id, ChatMessage(sender: .them, content: .text(text))))

                // Every few messages the partner takes a discovery step.
                if count % 3 == 0 {
                    let unrevealed = partner.discoverableCategories.filter { !conversation.theirRevealed.contains($0) }
                    if let category = unrevealed.first(where: { $0 != .basics }) ?? unrevealed.first {
                        Task { @MainActor in
                            await self.pause(1.5...2.5)
                            self.emitReveal(category, of: partner, in: id)
                        }
                    }
                } else if count % 5 == 4 {
                    Task { @MainActor in
                        await self.pause(1.5...2.5)
                        let pair = GameLibrary.randomWouldYouRather()
                        let session = GameSession(startedBy: .them, state: .wouldYouRather(
                            WouldYouRatherRound(optionA: pair.0, optionB: pair.1, myChoice: nil, theirChoice: Int.random(in: 0...1))))
                        self.emit(.message(conversationID: id, ChatMessage(sender: .them, content: .game(session))))
                    }
                }
            }
        default:
            break
        }
    }

    private func emitReveal(_ category: ProfileCategory, of partner: UserProfile, in conversationID: UUID) {
        let media = category == .media ? Array(partner.photos.prefix(4)) + partner.videos : []
        emit(.message(conversationID: conversationID,
                      ChatMessage(sender: .them, content: .reveal(category, items: partner.items(for: category), media: media))))
    }

    private func respondToReveal(_ category: ProfileCategory, in conversation: Conversation) {
        partners[conversation.id] = conversation.participant.id
        let partner = conversation.participant
        let id = conversation.id
        typeThen(id, 1.5...3) { [weak self] in
            guard let self else { return }
            let canReciprocate = partner.revealableCategories.contains(category) && !conversation.theirRevealed.contains(category)
            if canReciprocate && Double.random(in: 0...1) < 0.8 {
                self.emit(.message(conversationID: id, ChatMessage(sender: .them, content: .text("Oh nice! Okay, my turn ✨"))))
                self.emitReveal(category, of: partner, in: id)
            } else if let other = partner.discoverableCategories.first(where: { !conversation.theirRevealed.contains($0) && $0 != category }) {
                self.emit(.message(conversationID: id, ChatMessage(sender: .them, content: .text("Love that. Here's something different about me…"))))
                self.emitReveal(other, of: partner, in: id)
            } else {
                self.emit(.message(conversationID: id, ChatMessage(sender: .them, content: .text("Thanks for sharing that with me 💛"))))
            }
        }
    }

    private func respondToGame(_ session: GameSession, messageID: UUID, in conversation: Conversation) {
        partners[conversation.id] = conversation.participant.id
        let id = conversation.id
        var updated = session
        var needsUpdate = false

        switch session.state {
        case .question(var round) where round.theirAnswer == nil:
            round.theirAnswer = GameLibrary.partnerAnswers.randomElement()
            updated.state = .question(round); needsUpdate = true
        case .wouldYouRather(var round) where round.theirChoice == nil:
            round.theirChoice = Int.random(in: 0...1)
            updated.state = .wouldYouRather(round); needsUpdate = true
        case .twoTruths(var round) where round.author == .me && round.guess == nil:
            round.guess = Int.random(in: 0...2)
            updated.state = .twoTruths(round); needsUpdate = true
        case .challenge(var round) where round.theirStatus == .pending:
            round.theirStatus = Bool.random() ? .accepted : .done
            updated.state = .challenge(round); needsUpdate = true
        default:
            break
        }
        guard needsUpdate else { return }

        typeThen(id, 1.5...3.5) { [weak self] in
            guard let self else { return }
            let message = ChatMessage(id: messageID, sender: session.startedBy, content: .game(updated))
            self.emit(.update(conversationID: id, message))

            // After guessing your lie, the partner sometimes plays back.
            if case .twoTruths(let r) = updated.state, r.author == .me {
                let correct = r.guess == r.lieIndex
                self.emit(.message(conversationID: id, ChatMessage(sender: .them,
                    content: .text(correct ? "Ha! I knew it 😎 My turn…" : "Nooo, I was so sure 😂 My turn…"))))
                Task { @MainActor in
                    await self.pause(1.5...2.5)
                    let statements = GameLibrary.partnerTwoTruths.randomElement() ?? ["A", "B", "C"]
                    let session = GameSession(startedBy: .them, state: .twoTruths(
                        TwoTruthsRound(author: .them, statements: statements, lieIndex: Int.random(in: 0...2), guess: nil)))
                    self.emit(.message(conversationID: id, ChatMessage(sender: .them, content: .game(session))))
                }
            }
        }
    }
}
