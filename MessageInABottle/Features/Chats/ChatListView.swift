import SwiftUI

struct ChatListView: View {
    @Environment(AppModel.self) private var model
    @State private var search = ""
    @State private var conversationToDelete: Conversation?

    private var filtered: [Conversation] {
        let all = model.sortedConversations
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return all }
        return all.filter {
            $0.participant.name.localizedCaseInsensitiveContains(query)
                || $0.lastMessage?.previewText.localizedCaseInsensitiveContains(query) == true
        }
    }

    var body: some View {
        @Bindable var model = model

        NavigationStack(path: $model.chatPath) {
            List {
                if !model.incomingRequests.isEmpty && search.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.m) {
                                ForEach(model.incomingRequests) { request in
                                    RequestCard(request: request)
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.l)
                            .padding(.vertical, Theme.Spacing.xs)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    } header: {
                        sectionTitle("Connection requests", count: model.incomingRequests.count)
                    }
                }

                Section {
                    if filtered.isEmpty {
                        emptyState
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    ForEach(filtered) { convo in
                        NavigationLink(value: convo.id) {
                            ConversationRow(conversation: convo)
                        }
                        .listRowBackground(Theme.Palette.background)
                        .listRowSeparatorTint(Theme.Palette.hairline)
                        .swipeActions(edge: .leading) {
                            Button {
                                toggle(\.isPinned, for: convo)
                            } label: {
                                Label(convo.isPinned ? "Unpin" : "Pin", systemImage: convo.isPinned ? "pin.slash" : "pin")
                            }
                            .tint(Theme.Palette.accent)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                conversationToDelete = convo
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                toggle(\.isMuted, for: convo)
                            } label: {
                                Label(convo.isMuted ? "Unmute" : "Mute", systemImage: convo.isMuted ? "bell" : "bell.slash")
                            }
                            .tint(Theme.Palette.textSecondary)
                        }
                    }
                } header: {
                    if !filtered.isEmpty { sectionTitle("Conversations", count: nil) }
                }

                TabBarSpacer()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Chats")
            .searchable(text: $search, prompt: "Search conversations")
            .navigationDestination(for: UUID.self) { id in
                ChatView(conversationID: id)
            }
            .confirmationDialog("Delete this conversation?",
                                isPresented: Binding(get: { conversationToDelete != nil },
                                                     set: { if !$0 { conversationToDelete = nil } }),
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let convo = conversationToDelete {
                        withAnimation { model.conversations.removeAll { $0.id == convo.id } }
                    }
                    conversationToDelete = nil
                }
            } message: {
                Text("Messages and revealed information will be removed from this device.")
            }
            .onChange(of: model.chatPath) { _, newValue in
                model.setTabBar(hidden: !newValue.isEmpty, for: .chats)
            }
        }
    }

    private func toggle(_ keyPath: WritableKeyPath<Conversation, Bool>, for convo: Conversation) {
        guard let i = model.conversations.firstIndex(where: { $0.id == convo.id }) else { return }
        withAnimation { model.conversations[i][keyPath: keyPath].toggle() }
    }

    private func sectionTitle(_ title: String, count: Int?) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.ui(13, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.6)
            if let count {
                Text("\(count)")
                    .font(.roundedUI(11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.Palette.coral))
            }
        }
        .foregroundStyle(Theme.Palette.textSecondary)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: search.isEmpty ? "bubble.left.and.bubble.right" : "magnifyingglass")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.Palette.accent)
            Text(search.isEmpty ? "No conversations yet" : "No results")
                .font(.display(20, weight: .semibold))
            Text(search.isEmpty
                 ? "Open a bottle or connect with someone in Explore to start talking."
                 : "Try a different name or word.")
                .font(.ui(14))
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
            if search.isEmpty {
                Button("Throw a bottle") { model.selectedTab = .bottle }
                    .buttonStyle(PrimaryButtonStyle(fullWidth: false))
                    .padding(.top, Theme.Spacing.s)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            AvatarView(profile: conversation.participant, size: 54)
                .overlay(alignment: .topLeading) {
                    Image(systemName: conversation.origin.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Theme.Palette.deepOcean))
                        .overlay(Circle().strokeBorder(Theme.Palette.background, lineWidth: 2))
                        .offset(x: -4, y: -4)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(conversation.participant.firstName)
                        .font(.ui(16, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(conversation.participant.country.flag).font(.system(size: 13))
                    if conversation.isPinned {
                        Image(systemName: "pin.fill").font(.system(size: 10)).foregroundStyle(Theme.Palette.textTertiary)
                    }
                    if conversation.isMuted {
                        Image(systemName: "bell.slash.fill").font(.system(size: 10)).foregroundStyle(Theme.Palette.textTertiary)
                    }
                    Spacer()
                    Text(conversation.lastActivity.chatTimestamp)
                        .font(.ui(12))
                        .foregroundStyle(conversation.unreadCount > 0 ? Theme.Palette.accent : Theme.Palette.textTertiary)
                }
                HStack(alignment: .top) {
                    if conversation.isTyping {
                        TypingDots().frame(height: 18)
                        Text("typing…").font(.ui(14)).foregroundStyle(Theme.Palette.accent)
                    } else {
                        Text(previewPrefix + (conversation.lastMessage?.previewText ?? ""))
                            .font(.ui(14))
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.roundedUI(12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 22, minHeight: 22)
                            .background(Capsule().fill(conversation.isMuted ? Theme.Palette.textTertiary : Theme.Palette.accent))
                    }
                }
                DiscoveryMeter(progress: conversation.discoveryProgress)
                    .frame(width: 90)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
    }

    private var previewPrefix: String {
        conversation.lastMessage?.sender == .me ? "You: " : ""
    }
}

/// Tiny segmented meter showing how much of the other person you've discovered.
struct DiscoveryMeter: View {
    var progress: Double
    var segments = 6

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { i in
                Capsule()
                    .fill(Double(i) < progress * Double(segments) ? Theme.Palette.turquoise : Theme.Palette.hairline)
                    .frame(height: 3)
            }
        }
        .accessibilityLabel("Discovered \(Int(progress * 100)) percent of their profile")
    }
}

struct RequestCard: View {
    @Environment(AppModel.self) private var model
    let request: ConnectionRequest
    @State private var showProfile = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Button { showProfile = true } label: {
                HStack(spacing: Theme.Spacing.s) {
                    AvatarView(profile: request.profile, size: 40)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(request.profile.firstName), \(request.profile.age)")
                            .font(.ui(15, weight: .semibold))
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text(request.profile.country.flag + " " + request.profile.country.name)
                            .font(.ui(12))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
            if let note = request.note {
                Text("“\(note)”")
                    .font(.ui(13))
                    .italic()
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(2)
                    .frame(height: 36, alignment: .top)
            }
            HStack(spacing: Theme.Spacing.s) {
                Button("Decline") { Task { await model.respond(to: request, accept: false) } }
                    .buttonStyle(SecondaryButtonStyle(tint: Theme.Palette.textSecondary))
                Button("Accept") { Task { await model.respond(to: request, accept: true) } }
                    .buttonStyle(.primary)
            }
            .font(.ui(14, weight: .semibold))
            .controlSize(.small)
        }
        .frame(width: 260)
        .cardStyle(padding: Theme.Spacing.m)
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileDetailView(profile: request.profile)
            }
        }
    }
}

struct TypingDots: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Theme.Palette.accent)
                        .frame(width: 6, height: 6)
                        .opacity(0.35 + 0.65 * max(0, sin(t * 5 - Double(i) * 0.7)))
                        .offset(y: -2 * max(0, sin(t * 5 - Double(i) * 0.7)))
                }
            }
        }
    }
}

extension Date {
    var chatTimestamp: String {
        let cal = Calendar.current
        if cal.isDateInToday(self) { return formatted(date: .omitted, time: .shortened) }
        if cal.isDateInYesterday(self) { return "Yesterday" }
        if let days = cal.dateComponents([.day], from: self, to: .now).day, days < 7 {
            return formatted(.dateTime.weekday(.abbreviated))
        }
        return formatted(.dateTime.day().month(.abbreviated))
    }
}
