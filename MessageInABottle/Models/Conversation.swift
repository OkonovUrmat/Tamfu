import Foundation

enum ChatSender: String, Hashable, Codable {
    case me, them, system
}

enum ConversationOrigin: String, Hashable, Codable {
    case bottle, match, request

    var label: String {
        switch self {
        case .bottle: return "From a bottle"
        case .match: return "Mutual connection"
        case .request: return "Connection request"
        }
    }

    var icon: String {
        switch self {
        case .bottle: return "waterbottle"
        case .match: return "heart.circle"
        case .request: return "person.crop.circle.badge.checkmark"
        }
    }
}

struct ChatMessage: Identifiable, Hashable {
    enum Content: Hashable {
        case text(String)
        case media(MediaItem, caption: String?)
        /// Small centered note ("You found Maria's bottle").
        case system(String)
        /// `sender` revealed a profile category. Items are a snapshot at reveal time.
        case reveal(ProfileCategory, items: [String], media: [MediaItem])
        /// `sender` is curious about a category of the other person.
        case revealRequest(ProfileCategory)
        /// Both people have revealed the same category.
        case mutualReveal(ProfileCategory)
        case game(GameSession)
        /// Original bottle that started the conversation.
        case bottle(text: String, media: [MediaItem])
    }

    enum DeliveryState: String, Hashable {
        case sending, sent, read, failed
    }

    let id: UUID
    var sender: ChatSender
    var sentAt: Date
    var content: Content
    var delivery: DeliveryState
    /// Used by interactive prompts (reveal requests / "reveal yours too?").
    var isResolved: Bool

    init(id: UUID = UUID(), sender: ChatSender, sentAt: Date = .now, content: Content,
         delivery: DeliveryState = .sent, isResolved: Bool = false) {
        self.id = id
        self.sender = sender
        self.sentAt = sentAt
        self.content = content
        self.delivery = delivery
        self.isResolved = isResolved
    }

    var previewText: String {
        switch content {
        case .text(let t): return t
        case .media(let m, let caption):
            if let caption, !caption.isEmpty { return (m.isVideo ? "🎬 " : "📷 ") + caption }
            return m.isVideo ? "🎬 Video" : "📷 Photo"
        case .system(let t): return t
        case .reveal(let c, _, _): return "✨ Revealed \(c.phrase)"
        case .revealRequest(let c): return "🔎 Curious about \(c.phrase)"
        case .mutualReveal(let c): return "🤝 Both revealed \(c.phrase)"
        case .game(let g): return "🎲 \(g.kind.title)"
        case .bottle(let t, _): return "🍾 " + t
        }
    }

    var isBubble: Bool {
        switch content {
        case .text, .media: return true
        default: return false
        }
    }
}

struct Conversation: Identifiable, Hashable {
    let id: UUID
    var participant: UserProfile
    var origin: ConversationOrigin
    var messages: [ChatMessage]
    var myRevealed: Set<ProfileCategory>
    var theirRevealed: Set<ProfileCategory>
    var unreadCount: Int
    var isTyping: Bool
    var isMuted: Bool
    var isPinned: Bool
    let createdAt: Date

    init(id: UUID = UUID(), participant: UserProfile, origin: ConversationOrigin,
         messages: [ChatMessage] = [], myRevealed: Set<ProfileCategory> = [],
         theirRevealed: Set<ProfileCategory> = [], unreadCount: Int = 0,
         isTyping: Bool = false, isMuted: Bool = false, isPinned: Bool = false,
         createdAt: Date = .now) {
        self.id = id
        self.participant = participant
        self.origin = origin
        self.messages = messages
        self.myRevealed = myRevealed
        self.theirRevealed = theirRevealed
        self.unreadCount = unreadCount
        self.isTyping = isTyping
        self.isMuted = isMuted
        self.isPinned = isPinned
        self.createdAt = createdAt
    }

    var lastMessage: ChatMessage? { messages.last }
    var lastActivity: Date { messages.last?.sentAt ?? createdAt }

    /// Fraction of the other person's revealable profile that is now known.
    var discoveredCount: Int {
        theirRevealed.intersection(participant.discoverableCategories).count
    }

    var discoveryProgress: Double {
        let total = participant.discoverableCategories.count
        guard total > 0 else { return 1 }
        return min(1, Double(discoveredCount) / Double(total))
    }
}

/// Real-time events from the messaging backend.
enum ChatEvent {
    case typing(conversationID: UUID, isTyping: Bool)
    case message(conversationID: UUID, ChatMessage)
    case update(conversationID: UUID, ChatMessage)
    case revealed(conversationID: UUID, ProfileCategory)
    case newConversation(Conversation)
}

/// Connection requests (from Explore).
struct ConnectionRequest: Identifiable, Hashable {
    enum Direction: Hashable { case incoming, outgoing }
    enum State: Hashable { case pending, accepted, declined }

    let id: UUID
    let profile: UserProfile
    let direction: Direction
    var state: State
    let note: String?
    let createdAt: Date

    init(id: UUID = UUID(), profile: UserProfile, direction: Direction,
         state: State = .pending, note: String? = nil, createdAt: Date = .now) {
        self.id = id
        self.profile = profile
        self.direction = direction
        self.state = state
        self.note = note
        self.createdAt = createdAt
    }
}

enum DiscoveryEvent {
    case requestAccepted(ConnectionRequest, Conversation)
    case incomingRequest(ConnectionRequest)
}
