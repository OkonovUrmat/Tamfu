import SwiftUI

/// Explicit-consent flow for sharing a profile category, or asking about one.
/// Nothing is ever revealed without the user tapping the final confirm button.
struct RevealSheet: View {
    enum Mode: String, CaseIterable, Identifiable {
        case share = "Share about me"
        case ask = "Ask about them"
        var id: String { rawValue }
    }

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let conversation: Conversation
    var preselect: ProfileCategory?

    @State private var mode: Mode = .share
    @State private var selected: ProfileCategory?
    @State private var isWorking = false

    private var me: UserProfile { model.currentUser }
    private var name: String { conversation.participant.firstName }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if mode == .share {
                        shareList
                    } else {
                        askList
                    }
                }
                .padding(Theme.Spacing.xl)
                .padding(.bottom, 120)
            }
            .screenBackground()
            .navigationTitle(mode == .share ? "Reveal to \(name)" : "Curious about \(name)?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                if mode == .share, let category = selected {
                    confirmBar(category)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(Theme.Motion.snappy, value: selected)
            .animation(Theme.Motion.snappy, value: mode)
        }
        .onAppear {
            if let preselect, isShareable(preselect) { selected = preselect }
        }
        .onChange(of: mode) { _, _ in selected = nil }
    }

    // MARK: Share

    private func isShareable(_ c: ProfileCategory) -> Bool {
        me.visibility(of: c) != .hidden && me.hasContent(for: c) && !conversation.myRevealed.contains(c)
    }

    private var shareList: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Pick one thing to share. \(name) will see exactly what's previewed below — once shared, it stays in this chat.")
                .font(.ui(14))
                .foregroundStyle(Theme.Palette.textSecondary)

            ForEach(ProfileCategory.allCases) { category in
                let shared = conversation.myRevealed.contains(category)
                let hidden = me.visibility(of: category) == .hidden
                let empty = !me.hasContent(for: category)
                Button {
                    guard isShareable(category) else { return }
                    selected = selected == category ? nil : category
                } label: {
                    VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                        HStack(spacing: Theme.Spacing.m) {
                            Image(systemName: category.icon)
                                .font(.system(size: 16, weight: .medium))
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(selected == category ? Theme.Palette.accent : Theme.Palette.accentSoft))
                                .foregroundStyle(selected == category ? .white : Theme.Palette.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.title)
                                    .font(.ui(15, weight: .semibold))
                                    .foregroundStyle(Theme.Palette.textPrimary)
                                Text(shared ? "Already shared" : hidden ? "Hidden in your settings" : empty ? "Nothing added yet" : summary(category))
                                    .font(.ui(12))
                                    .foregroundStyle(Theme.Palette.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: shared ? "checkmark.circle.fill" : hidden ? "lock.fill" : selected == category ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(shared ? Theme.Palette.success : hidden ? Theme.Palette.textTertiary : Theme.Palette.accent)
                        }
                        if selected == category {
                            preview(category)
                        }
                    }
                    .padding(Theme.Spacing.m)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                            .fill(Theme.Palette.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                            .strokeBorder(selected == category ? Theme.Palette.accent : Theme.Palette.hairline,
                                          lineWidth: selected == category ? 1.5 : 0.5)
                    )
                    .opacity(isShareable(category) || shared ? 1 : 0.55)
                }
                .buttonStyle(.plain)
                .disabled(!isShareable(category))
            }

            Text("Tip: choose what's shareable in Profile → Profile categories.")
                .font(.ui(12))
                .foregroundStyle(Theme.Palette.textTertiary)
        }
    }

    private func summary(_ c: ProfileCategory) -> String {
        me.items(for: c).prefix(3).joined(separator: " · ")
    }

    @ViewBuilder
    private func preview(_ c: ProfileCategory) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("PREVIEW")
                .font(.ui(10, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.Palette.textTertiary)
            if c == .media {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(me.photos.prefix(4)) + me.videos) { item in
                            MediaThumbnail(item: item, cornerRadius: 10).frame(width: 64, height: 80)
                        }
                    }
                }
            } else {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(me.items(for: c), id: \.self) { ChipView(text: $0) }
                }
            }
        }
        .transition(.opacity)
    }

    private func confirmBar(_ category: ProfileCategory) -> some View {
        VStack(spacing: Theme.Spacing.s) {
            Button {
                isWorking = true
                Task {
                    await model.reveal(category, in: conversation.id)
                    isWorking = false
                    dismiss()
                }
            } label: {
                Label("Reveal my \(category.phrase) to \(name)", systemImage: "sparkles")
            }
            .buttonStyle(.primary)
            .disabled(isWorking)
            Text("Only \(name) will see this.")
                .font(.ui(12))
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.m)
        .background(.ultraThinMaterial)
    }

    // MARK: Ask

    private var askList: some View {
        let askable = ProfileCategory.allCases.filter {
            !conversation.theirRevealed.contains($0) && conversation.participant.visibility(of: $0) != .public
        }
        let pending: Set<ProfileCategory> = Set(conversation.messages.compactMap { (m: ChatMessage) -> ProfileCategory? in
            if m.sender == .me, case .revealRequest(let c) = m.content { return c }
            return nil
        })
        return VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Send a gentle nudge. \(name) decides whether to share — there's no pressure either way.")
                .font(.ui(14))
                .foregroundStyle(Theme.Palette.textSecondary)
            if askable.isEmpty {
                Text("You've discovered everything \(name) has shared. ✨")
                    .font(.ui(15, weight: .medium))
                    .padding(.top, Theme.Spacing.l)
            }
            ForEach(askable) { category in
                let isPending = pending.contains(category)
                HStack(spacing: Theme.Spacing.m) {
                    Image(systemName: category.icon)
                        .foregroundStyle(Theme.Palette.accent)
                        .frame(width: 30)
                    Text("Their \(category.phrase)")
                        .font(.ui(15, weight: .medium))
                    Spacer()
                    Button(isPending ? "Asked" : "Ask") {
                        Task {
                            await model.requestReveal(category, in: conversation.id)
                            dismiss()
                        }
                    }
                    .font(.ui(14, weight: .semibold))
                    .buttonStyle(.bordered)
                    .tint(Theme.Palette.accent)
                    .disabled(isPending)
                }
                .padding(Theme.Spacing.m)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.medium).fill(Theme.Palette.surface))
            }
        }
    }
}
