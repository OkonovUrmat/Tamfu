import SwiftUI

// MARK: - Reveal card

/// "Alex revealed their hobbies to you!" — tap to open, then an invitation to reciprocate.
struct RevealCard: View {
    @Environment(AppModel.self) private var model
    let message: ChatMessage
    let category: ProfileCategory
    let items: [String]
    let media: [MediaItem]
    let conversation: Conversation
    let vm: ChatViewModel

    @State private var isOpen = false

    private var fromThem: Bool { message.sender == .them }
    private var name: String { conversation.participant.firstName }
    private var iAlreadyShared: Bool { conversation.myRevealed.contains(category) }
    private var canReciprocate: Bool { model.currentUser.revealableCategories.contains(category) }

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            card
            if fromThem && isOpen && !message.isResolved {
                reciprocatePrompt
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.vertical, Theme.Spacing.s)
        .onAppear { if !fromThem || message.isResolved { isOpen = true } }
    }

    private var card: some View {
        Button {
            withAnimation(Theme.Motion.bouncy) { isOpen.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                HStack(spacing: Theme.Spacing.m) {
                    ZStack {
                        Circle().fill(.white.opacity(0.16))
                        Image(systemName: category.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .symbolEffect(.bounce, value: isOpen)
                    }
                    .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fromThem ? "\(name) revealed their \(category.phrase) to you!" : "You revealed your \(category.phrase)")
                            .font(.ui(15, weight: .semibold))
                            .multilineTextAlignment(.leading)
                        Text(isOpen ? category.title : "Tap to open")
                            .font(.ui(12))
                            .opacity(0.75)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: isOpen ? "chevron.up" : "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .opacity(0.8)
                }

                if isOpen {
                    VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                        if !items.isEmpty && category != .media {
                            FlowLayout(spacing: 6, lineSpacing: 6) {
                                ForEach(items, id: \.self) { ChipView(text: $0, style: .onDark) }
                            }
                        }
                        if !media.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(media) { item in
                                        Button { vm.open(media, selected: item) } label: {
                                            MediaThumbnail(item: item, cornerRadius: 12)
                                                .frame(width: 96, height: 120)
                                        }
                                        .buttonStyle(.pressable)
                                    }
                                }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                }
            }
            .foregroundStyle(.white)
            .padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .fill(fromThem ? AnyShapeStyle(Theme.Gradients.night) : AnyShapeStyle(Theme.Gradients.accent))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Theme.Palette.deepOcean.opacity(0.18), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.pressable)
        .padding(.leading, fromThem ? 0 : 50)
        .padding(.trailing, fromThem ? 50 : 0)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isOpen)
    }

    @ViewBuilder
    private var reciprocatePrompt: some View {
        VStack(spacing: Theme.Spacing.m) {
            if iAlreadyShared {
                Label("You've already shared your \(category.phrase)", systemImage: "checkmark.circle.fill")
                    .font(.ui(13, weight: .medium))
                    .foregroundStyle(Theme.Palette.success)
            } else {
                Text(canReciprocate ? "Would you like to reveal your \(category.phrase) too?" : "Want to share something about yourself too?")
                    .font(.ui(14, weight: .medium))
                    .foregroundStyle(Theme.Palette.textPrimary)
                HStack(spacing: Theme.Spacing.s) {
                    if canReciprocate {
                        promptButton("Reveal mine", filled: true) {
                            vm.openReveal(preselect: category)
                        }
                    }
                    promptButton("Something else", filled: !canReciprocate) {
                        vm.openReveal()
                    }
                    promptButton("Not now", filled: false) {
                        model.resolvePrompt(message.id, in: conversation.id)
                    }
                }
            }
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous).fill(Theme.Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous).strokeBorder(Theme.Palette.hairline))
        .padding(.trailing, 50)
    }
}

@MainActor
func promptButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.ui(13, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .foregroundStyle(filled ? .white : Theme.Palette.accent)
            .background(Capsule().fill(filled ? AnyShapeStyle(Theme.Gradients.accent) : AnyShapeStyle(Theme.Palette.accentSoft)))
    }
    .buttonStyle(.pressable)
}

// MARK: - Reveal request

struct RevealRequestCard: View {
    @Environment(AppModel.self) private var model
    let message: ChatMessage
    let category: ProfileCategory
    let conversation: Conversation
    let vm: ChatViewModel

    private var fromThem: Bool { message.sender == .them }
    private var name: String { conversation.participant.firstName }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Palette.accent)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.Palette.accentSoft))
                Text(fromThem ? "\(name) wants to know your \(category.phrase)" : "You asked about \(name)'s \(category.phrase)")
                    .font(.ui(15, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer(minLength: 0)
            }
            status
        }
        .padding(Theme.Spacing.l)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .fill(Theme.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .foregroundStyle(Theme.Palette.accent.opacity(0.5))
        )
        .padding(.leading, fromThem ? 0 : 50)
        .padding(.trailing, fromThem ? 50 : 0)
        .padding(.vertical, Theme.Spacing.s)
    }

    @ViewBuilder
    private var status: some View {
        if fromThem {
            if conversation.myRevealed.contains(category) {
                Label("You shared it", systemImage: "checkmark.circle.fill")
                    .font(.ui(13, weight: .medium)).foregroundStyle(Theme.Palette.success)
            } else if message.isResolved {
                Text("Maybe later").font(.ui(13)).foregroundStyle(Theme.Palette.textTertiary)
            } else if model.currentUser.visibility(of: category) == .hidden || !model.currentUser.hasContent(for: category) {
                HStack {
                    Text(model.currentUser.hasContent(for: category) ? "This is hidden in your settings." : "You haven't filled this in yet.")
                        .font(.ui(13)).foregroundStyle(Theme.Palette.textSecondary)
                    Spacer()
                    promptButton("Dismiss", filled: false) { model.resolvePrompt(message.id, in: conversation.id) }
                        .frame(width: 110)
                }
            } else {
                HStack(spacing: Theme.Spacing.s) {
                    promptButton("Reveal", filled: true) { vm.openReveal(preselect: category) }
                    promptButton("Not now", filled: false) { model.resolvePrompt(message.id, in: conversation.id) }
                }
            }
        } else {
            if conversation.theirRevealed.contains(category) {
                Label("\(name) shared it", systemImage: "checkmark.circle.fill")
                    .font(.ui(13, weight: .medium)).foregroundStyle(Theme.Palette.success)
            } else {
                Text("Waiting — sharing is always their choice.")
                    .font(.ui(13)).foregroundStyle(Theme.Palette.textTertiary)
            }
        }
    }
}

// MARK: - Mutual reveal

struct MutualRevealCard: View {
    @Environment(AppModel.self) private var model
    let category: ProfileCategory
    let conversation: Conversation
    @State private var burst = false

    private var common: [String] {
        let mine = Set(model.currentUser.items(for: category).map { $0.lowercased() })
        return conversation.participant.items(for: category).filter { mine.contains($0.lowercased()) }
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    Image(systemName: "sparkle")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.Palette.turquoise)
                        .offset(x: burst ? cos(Double(i) / 8 * 2 * .pi) * 36 : 0,
                                y: burst ? sin(Double(i) / 8 * 2 * .pi) * 22 : 0)
                        .opacity(burst ? 0 : 1)
                }
                Text("🤝").font(.system(size: 28))
            }
            .frame(height: 40)
            Text("Both of you revealed your \(category.phrase)!")
                .font(.display(17, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .multilineTextAlignment(.center)
            if !common.isEmpty {
                Text("In common: " + common.joined(separator: ", "))
                    .font(.ui(13, weight: .medium))
                    .foregroundStyle(Theme.Palette.accent)
                    .multilineTextAlignment(.center)
            } else {
                Text("Different tastes — more to talk about.")
                    .font(.ui(13))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .fill(Theme.Palette.accentSoft)
        )
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.s)
        .onAppear { withAnimation(.easeOut(duration: 1.0)) { burst = true } }
    }
}
