import SwiftUI
import PhotosUI

struct ChatView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let conversationID: UUID
    @State private var vm: ChatViewModel
    @FocusState private var inputFocused: Bool

    init(conversationID: UUID) {
        self.conversationID = conversationID
        _vm = State(initialValue: ChatViewModel(conversationID: conversationID))
    }

    var body: some View {
        if let convo = model.conversation(conversationID) {
            content(convo)
        } else {
            ContentUnavailableView("Conversation unavailable", systemImage: "bubble.left.and.exclamationmark.bubble.right",
                                   description: Text("This conversation was removed."))
        }
    }

    private func content(_ convo: Conversation) -> some View {
        VStack(spacing: 0) {
            DiscoveryStrip(conversation: convo) { vm.openReveal() }
            messages(convo)
            inputBar(convo)
        }
        .background(ChatBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) { titleView(convo) }
            ToolbarItem(placement: .primaryAction) { menu(convo) }
        }
        .onAppear { model.markRead(conversationID) }
        .onChange(of: convo.messages.count) { _, _ in model.markRead(conversationID) }
        .onChange(of: vm.mediaSelection) { _, item in
            Task { await vm.sendMedia(item, using: model) }
        }
        .sheet(isPresented: $vm.showGames) {
            GamesSheet(partnerName: convo.participant.firstName) { session in
                vm.startGame(session, using: model)
            }
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(Theme.Radius.xl)
        }
        .sheet(isPresented: $vm.showReveal) {
            RevealSheet(conversation: convo, preselect: vm.revealPreselect)
                .presentationDetents([.large])
                .presentationCornerRadius(Theme.Radius.xl)
        }
        .sheet(isPresented: $vm.showProfile) {
            NavigationStack {
                ProfileDetailView(profile: convo.participant, revealed: convo.theirRevealed)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { vm.showProfile = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $vm.showReport) {
            ReportSheet(user: convo.participant.ref) {}
        }
        .fullScreenCover(item: $vm.viewer) { payload in
            MediaViewer(items: payload.items, selection: payload.selected.id)
        }
        .confirmationDialog("Block \(convo.participant.firstName)?", isPresented: $vm.confirmBlock, titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                Task { await model.block(convo.participant.ref) }
            }
        } message: {
            Text("This conversation will be removed and they won't be able to contact you again.")
        }
    }

    // MARK: Header

    private func titleView(_ convo: Conversation) -> some View {
        Button { vm.showProfile = true } label: {
            HStack(spacing: 10) {
                AvatarView(profile: convo.participant, size: 34)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(convo.participant.firstName) \(convo.participant.country.flag)")
                        .font(.ui(16, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Group {
                        if convo.isTyping {
                            Text("typing…").foregroundStyle(Theme.Palette.accent)
                        } else if convo.participant.isOnline {
                            Text("online").foregroundStyle(Theme.Palette.online)
                        } else {
                            Text("last seen \(convo.participant.lastActive.formatted(.relative(presentation: .named)))")
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }
                    .font(.ui(12))
                    .contentTransition(.opacity)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View \(convo.participant.firstName)'s profile")
    }

    private func menu(_ convo: Conversation) -> some View {
        Menu {
            Button { vm.showProfile = true } label: { Label("View profile", systemImage: "person.crop.circle") }
            Button { vm.openReveal() } label: { Label("Reveal something", systemImage: "sparkles") }
            Button { vm.showGames = true } label: { Label("Play a game", systemImage: "dice") }
            Divider()
            Button { vm.showReport = true } label: { Label("Report", systemImage: "exclamationmark.bubble") }
            Button(role: .destructive) { vm.confirmBlock = true } label: { Label("Block", systemImage: "hand.raised") }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 18))
        }
    }

    // MARK: Messages

    private func messages(_ convo: Conversation) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(convo.messages.enumerated()), id: \.element.id) { index, message in
                        if index == 0 || !Calendar.current.isDate(message.sentAt, inSameDayAs: convo.messages[index - 1].sentAt) {
                            DaySeparator(date: message.sentAt)
                        }
                        MessageRow(
                            message: message,
                            conversation: convo,
                            isLastInGroup: isLastInGroup(index, in: convo.messages),
                            vm: vm
                        )
                        .id(message.id)
                        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                    }
                    if convo.isTyping {
                        HStack {
                            TypingDots()
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(BubbleShape(isMine: false).fill(Theme.Palette.bubbleTheirs))
                            Spacer()
                        }
                        .transition(.scale(scale: 0.6, anchor: .bottomLeading).combined(with: .opacity))
                    }
                    Color.clear.frame(height: 4).id("bottom")
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.top, Theme.Spacing.m)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: convo.messages.count) { _, _ in
                withAnimation(Theme.Motion.snappy) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: convo.isTyping) { _, typing in
                if typing { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
            }
            .onChange(of: inputFocused) { _, focused in
                if focused {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }
            }
        }
    }

    private func isLastInGroup(_ index: Int, in messages: [ChatMessage]) -> Bool {
        guard index + 1 < messages.count else { return true }
        let next = messages[index + 1]
        return next.sender != messages[index].sender || !next.isBubble
            || next.sentAt.timeIntervalSince(messages[index].sentAt) > 300
    }

    // MARK: Input

    private func inputBar(_ convo: Conversation) -> some View {
        VStack(spacing: 0) {
            Divider().overlay(Theme.Palette.hairline)
            HStack(alignment: .bottom, spacing: Theme.Spacing.s) {
                PhotosPicker(selection: $vm.mediaSelection, matching: .any(of: [.images, .videos])) {
                    toolbarIcon(vm.isLoadingMedia ? "hourglass" : "photo.on.rectangle")
                }
                .disabled(vm.isLoadingMedia)
                .accessibilityLabel("Send photo or video")

                Button { vm.showGames = true } label: { toolbarIcon("dice") }
                    .accessibilityLabel("Mini-games")

                Button { vm.openReveal() } label: { toolbarIcon("sparkles") }
                    .accessibilityLabel("Reveal or ask")

                HStack(alignment: .bottom) {
                    TextField("Message", text: $vm.draft, axis: .vertical)
                        .font(.ui(16))
                        .lineLimit(1...5)
                        .focused($inputFocused)
                        .padding(.vertical, 9)
                        .submitLabel(.send)
                }
                .padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.Palette.surfaceMuted))

                Button { vm.sendText(using: model) } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(vm.canSend ? AnyShapeStyle(Theme.Gradients.accent) : AnyShapeStyle(Theme.Palette.textTertiary.opacity(0.5))))
                }
                .disabled(!vm.canSend)
                .sensoryFeedback(.impact(weight: .light), trigger: convo.messages.count)
                .accessibilityLabel("Send")
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
            .background(.bar)
        }
    }

    private func toolbarIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 19, weight: .regular))
            .foregroundStyle(Theme.Palette.accent)
            .frame(width: 34, height: 38)
    }
}

// MARK: - Supporting views

struct ChatBackground: View {
    var body: some View {
        ZStack {
            Theme.Palette.background
            LinearGradient(colors: [Theme.Palette.turquoise.opacity(0.06), .clear, Theme.Palette.deepOcean.opacity(0.04)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .ignoresSafeArea()
    }
}

struct DaySeparator: View {
    let date: Date

    var body: some View {
        Text(label)
            .font(.ui(12, weight: .semibold))
            .foregroundStyle(Theme.Palette.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(Theme.Palette.surfaceMuted))
            .padding(.vertical, Theme.Spacing.s)
    }

    private var label: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

/// "You know 2 of 7 things about Maria" + reveal shortcut.
struct DiscoveryStrip: View {
    let conversation: Conversation
    var onReveal: () -> Void

    var body: some View {
        let total = conversation.participant.discoverableCategories.count
        HStack(spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Discovered \(conversation.discoveredCount) of \(total) · you shared \(conversation.myRevealed.count)")
                    .font(.ui(12, weight: .medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .contentTransition(.numericText())
                DiscoveryMeter(progress: conversation.discoveryProgress, segments: max(1, total))
            }
            Spacer()
            Button(action: onReveal) {
                Label("Reveal", systemImage: "sparkles")
                    .font(.ui(13, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Theme.Palette.accentSoft))
                    .foregroundStyle(Theme.Palette.accent)
            }
            .buttonStyle(.pressable)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        .background(Theme.Palette.surface.opacity(0.8))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.Palette.hairline).frame(height: 0.5) }
        .animation(Theme.Motion.snappy, value: conversation.theirRevealed)
    }
}

/// Chat bubble: rounded with a tighter corner where the "tail" would be.
struct BubbleShape: Shape {
    var isMine: Bool
    var hasTail = true

    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 18
        let tail: CGFloat = hasTail ? 6 : r
        return UnevenRoundedRectangle(
            topLeadingRadius: r,
            bottomLeadingRadius: isMine ? r : tail,
            bottomTrailingRadius: isMine ? tail : r,
            topTrailingRadius: r,
            style: .continuous
        ).path(in: rect)
    }
}
