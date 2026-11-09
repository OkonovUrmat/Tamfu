import Foundation

/// Every mini-game registers a kind. To add a new game:
/// 1. add a case here + metadata,
/// 2. add a state to `GameState`,
/// 3. add its setup UI and in-chat card (see Features/Chats/Games),
/// 4. teach the backend / simulator how the partner responds.
enum GameKind: String, CaseIterable, Identifiable, Hashable, Codable {
    case questionCards, wouldYouRather, twoTruths, challenge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .questionCards: return "Question Cards"
        case .wouldYouRather: return "Would You Rather"
        case .twoTruths: return "Two Truths & a Lie"
        case .challenge: return "Random Challenge"
        }
    }

    var subtitle: String {
        switch self {
        case .questionCards: return "Pick a theme, both answer one question"
        case .wouldYouRather: return "Two scenarios. Choose your side."
        case .twoTruths: return "Write three statements — they spot the lie"
        case .challenge: return "A small, harmless dare for both of you"
        }
    }

    var icon: String {
        switch self {
        case .questionCards: return "rectangle.on.rectangle.angled"
        case .wouldYouRather: return "arrow.left.arrow.right"
        case .twoTruths: return "theatermask.and.paintbrush"
        case .challenge: return "flag.checkered"
        }
    }

    var seed: Int {
        switch self {
        case .questionCards: return 0
        case .wouldYouRather: return 3
        case .twoTruths: return 8
        case .challenge: return 2
        }
    }
}

struct GameSession: Identifiable, Hashable {
    let id: UUID
    let startedBy: ChatSender
    var state: GameState

    init(id: UUID = UUID(), startedBy: ChatSender, state: GameState) {
        self.id = id
        self.startedBy = startedBy
        self.state = state
    }

    var kind: GameKind {
        switch state {
        case .question: return .questionCards
        case .wouldYouRather: return .wouldYouRather
        case .twoTruths: return .twoTruths
        case .challenge: return .challenge
        }
    }

    var isComplete: Bool {
        switch state {
        case .question(let r): return r.myAnswer != nil && r.theirAnswer != nil
        case .wouldYouRather(let r): return r.myChoice != nil && r.theirChoice != nil
        case .twoTruths(let r): return r.guess != nil
        case .challenge(let r): return r.myStatus != .pending && r.theirStatus != .pending
        }
    }
}

enum GameState: Hashable {
    case question(QuestionRound)
    case wouldYouRather(WouldYouRatherRound)
    case twoTruths(TwoTruthsRound)
    case challenge(ChallengeRound)
}

struct QuestionRound: Hashable {
    var category: QuestionCategory
    var question: String
    var myAnswer: String?
    var theirAnswer: String?
}

struct WouldYouRatherRound: Hashable {
    var optionA: String
    var optionB: String
    var myChoice: Int?
    var theirChoice: Int?
}

struct TwoTruthsRound: Hashable {
    /// Who wrote the statements.
    var author: ChatSender
    var statements: [String]
    var lieIndex: Int
    /// Guess made by the other participant.
    var guess: Int?
}

enum ChallengeStatus: String, Hashable {
    case pending, accepted, done, passed

    var label: String {
        switch self {
        case .pending: return "Thinking…"
        case .accepted: return "Accepted"
        case .done: return "Done ✓"
        case .passed: return "Passed"
        }
    }
}

struct ChallengeRound: Hashable {
    var text: String
    var myStatus: ChallengeStatus
    var theirStatus: ChallengeStatus
}

enum QuestionCategory: String, CaseIterable, Identifiable, Hashable, Codable {
    case love, personality, childhood, philosophy, travel, dreams, funny, deep, random

    var id: String { rawValue }

    var title: String {
        switch self {
        case .love: return "Love & Relationships"
        case .personality: return "Personality"
        case .childhood: return "Childhood"
        case .philosophy: return "Philosophy"
        case .travel: return "Travel"
        case .dreams: return "Dreams & Goals"
        case .funny: return "Funny"
        case .deep: return "Deep Conversations"
        case .random: return "Random"
        }
    }

    var icon: String {
        switch self {
        case .love: return "heart"
        case .personality: return "person.fill.questionmark"
        case .childhood: return "teddybear"
        case .philosophy: return "brain"
        case .travel: return "airplane"
        case .dreams: return "star"
        case .funny: return "face.smiling"
        case .deep: return "water.waves"
        case .random: return "shuffle"
        }
    }
}
