import SwiftUI

struct MessageRow: View {
    let message: ChatMessage
    let conversation: Conversation
    var isLastInGroup: Bool
    let vm: ChatViewModel

    var body: some View {
        switch message.content {
        case .text(let text):
            TextBubble(text: text, message: message, isLastInGroup: isLastInGroup)
        case .media(let item, let caption):
            MediaBubble(item: item, caption: caption, message: message) {
                vm.open([item], selected: item)
            }
        case .system(let text):
            SystemNote(text: text)
        case .bottle(let text, let media):
            BottleOriginCard(text: text, media: media, sender: message.sender,
                             partnerName: conversation.participant.firstName, date: message.sentAt) { item in
                vm.open(media, selected: item)
            }
        case .reveal(let category, let items, let media):
            RevealCard(message: message, category: category, items: items, media: media,
                       conversation: conversation, vm: vm)
        case .revealRequest(let category):
            RevealRequestCard(message: message, category: category, conversation: conversation, vm: vm)
        case .mutualReveal(let category):
            MutualRevealCard(category: category, conversation: conversation)
        case .game(let session):
            GameCardView(message: message, session: session, partnerName: conversation.participant.firstName, vm: vm)
        }
    }
}

// MARK: - Bubbles

struct TextBubble: View {
    let text: String
    let message: ChatMessage
    var isLastInGroup: Bool

    private var isMine: Bool { message.sender == .me }

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 60) }
            VStack(alignment: .trailing, spacing: 3) {
                Text(text)
                    .font(.ui(16))
                    .foregroundStyle(isMine ? .white : Theme.Palette.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                MessageMeta(message: message, onDark: isMine)
            }
            .padding(.horizontal, 14)
            .padding(.top, 9)
            .padding(.bottom, 7)
            .background(
                BubbleShape(isMine: isMine, hasTail: isLastInGroup)
                    .fill(isMine ? AnyShapeStyle(Theme.Palette.bubbleMine) : AnyShapeStyle(Theme.Palette.bubbleTheirs))
                    .shadow(color: .black.opacity(isMine ? 0 : 0.04), radius: 3, x: 0, y: 1)
            )
            .contextMenu {
                Button { UIPasteboard.general.string = text } label: { Label("Copy", systemImage: "doc.on.doc") }
            }
            if !isMine { Spacer(minLength: 60) }
        }
        .padding(.bottom, isLastInGroup ? 6 : 0)
    }
}

struct MessageMeta: View {
    let message: ChatMessage
    var onDark: Bool

    var body: some View {
        HStack(spacing: 3) {
            Text(message.sentAt.formatted(date: .omitted, time: .shortened))
            if message.sender == .me {
                switch message.delivery {
                case .sending: Image(systemName: "clock")
                case .sent: Image(systemName: "checkmark")
                case .read: Image(systemName: "checkmark.circle.fill")
                case .failed: Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Theme.Palette.danger)
                }
            }
        }
        .font(.ui(10.5))
        .foregroundStyle(onDark ? .white.opacity(0.7) : Theme.Palette.textTertiary)
    }
}

struct MediaBubble: View {
    let item: MediaItem
    let caption: String?
    let message: ChatMessage
    var onOpen: () -> Void

    private var isMine: Bool { message.sender == .me }

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 60) }
            VStack(alignment: .leading, spacing: 6) {
                Button(action: onOpen) {
                    MediaThumbnail(item: item, cornerRadius: 14)
                        .frame(width: 230, height: item.isVideo ? 150 : 280)
                }
                .buttonStyle(.pressable)
                if let caption, !caption.isEmpty {
                    Text(caption)
                        .font(.ui(15))
                        .foregroundStyle(isMine ? .white : Theme.Palette.textPrimary)
                        .padding(.horizontal, 6)
                }
                HStack {
                    Spacer()
                    MessageMeta(message: message, onDark: isMine)
                }
                .padding(.horizontal, 6)
            }
            .padding(5)
            .background(
                BubbleShape(isMine: isMine)
                    .fill(isMine ? AnyShapeStyle(Theme.Palette.bubbleMine) : AnyShapeStyle(Theme.Palette.bubbleTheirs))
            )
            if !isMine { Spacer(minLength: 60) }
        }
        .padding(.bottom, 6)
    }
}

struct SystemNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.ui(12.5, weight: .medium))
            .foregroundStyle(Theme.Palette.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(Theme.Palette.surfaceMuted.opacity(0.8)))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }
}

/// The bottle that started the conversation, rendered as a parchment letter.
struct BottleOriginCard: View {
    let text: String
    let media: [MediaItem]
    let sender: ChatSender
    let partnerName: String
    let date: Date
    var onOpenMedia: (MediaItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(spacing: 8) {
                BottleIllustration(size: 34, showsScroll: false).frame(width: 22)
                Text(sender == .me ? "Your bottle" : "\(partnerName)'s bottle")
                    .font(.ui(12, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(Color(hex: 0x8C806A))
                Spacer()
                Text(date.chatTimestamp)
                    .font(.ui(11))
                    .foregroundStyle(Color(hex: 0x8C806A))
            }
            if !text.isEmpty {
                Text(text)
                    .font(.display(18, weight: .regular))
                    .foregroundStyle(Color(hex: 0x2B2A26))
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(media) { item in
                Button { onOpenMedia(item) } label: {
                    MediaThumbnail(item: item, cornerRadius: 12).frame(height: 170)
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(Theme.Spacing.l)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xFCF6E6), Color(hex: 0xF1E5C8)], startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .strokeBorder(Color(hex: 0xE2D3AE), lineWidth: 1)
        )
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
    }
}
