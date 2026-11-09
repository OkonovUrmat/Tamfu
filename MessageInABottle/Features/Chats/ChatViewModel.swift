import SwiftUI
import PhotosUI

@MainActor
@Observable
final class ChatViewModel {
    let conversationID: UUID
    var draft = ""
    var mediaSelection: PhotosPickerItem?
    var isLoadingMedia = false

    // Sheets
    var showGames = false
    var showReveal = false
    var revealPreselect: ProfileCategory?
    var showProfile = false
    var showReport = false
    var confirmBlock = false
    var viewer: MediaViewerPayload?

    init(conversationID: UUID) {
        self.conversationID = conversationID
    }

    var canSend: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func sendText(using model: AppModel) {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        Task { await model.send(.text(text), in: conversationID) }
    }

    func sendMedia(_ item: PhotosPickerItem?, using model: AppModel) async {
        guard let item else { return }
        isLoadingMedia = true
        defer {
            isLoadingMedia = false
            mediaSelection = nil
        }
        guard let media = await MediaPickerLoader.load(item) else {
            model.showToast("Couldn't load that file.", icon: "exclamationmark.triangle", style: .error)
            return
        }
        await model.send(.media(media, caption: nil), in: conversationID)
    }

    func openReveal(preselect: ProfileCategory? = nil) {
        revealPreselect = preselect
        showReveal = true
    }

    func startGame(_ session: GameSession, using model: AppModel) {
        showGames = false
        Task { await model.send(.game(session), in: conversationID) }
    }

    /// Applies the current user's move to a game card and notifies the backend.
    func play(_ message: ChatMessage, newState: GameState, using model: AppModel) {
        guard case .game(var session) = message.content else { return }
        session.state = newState
        var updated = message
        updated.content = .game(session)
        Task { await model.updateMessage(updated, in: conversationID) }
    }

    func open(_ items: [MediaItem], selected: MediaItem) {
        viewer = MediaViewerPayload(items: items, selected: selected)
    }
}

struct MediaViewerPayload: Identifiable {
    let items: [MediaItem]
    let selected: MediaItem
    var id: UUID { selected.id }
}
