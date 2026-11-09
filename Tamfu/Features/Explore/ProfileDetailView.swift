import SwiftUI

/// Public profile page. Categories set to "In chats" appear as locked cards —
/// they can only be revealed voluntarily inside a conversation.
struct ProfileDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let profile: UserProfile
    var isPreview = false
    /// Categories already revealed to the viewer (when opened from a chat).
    var revealed: Set<ProfileCategory> = []

    @State private var page = 0
    @State private var viewerItem: MediaItem?
    @State private var showRequestSheet = false
    @State private var showReport = false
    @State private var confirmBlock = false

    /// The server strips the city from profiles whose owners hide their location.
    private var showsLocation: Bool {
        isPreview ? model.settings.privacy.showLocation : !profile.city.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                gallery
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    identity
                    if !profile.bio.isEmpty { intro }
                    if isVisible(.media), !profile.videos.isEmpty { videos }
                    details
                    lockedCategories
                    if !isPreview { safetyFooter }
                }
                .padding(Theme.Spacing.xl)
                .padding(.bottom, 100)
            }
        }
        .ignoresSafeArea(edges: .top)
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if !isPreview {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { showReport = true } label: { Label("Report", systemImage: "exclamationmark.bubble") }
                        Button(role: .destructive) { confirmBlock = true } label: { Label("Block", systemImage: "hand.raised") }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(.black.opacity(0.3)))
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !isPreview { connectBar }
        }
        .fullScreenCover(item: $viewerItem) { item in
            MediaViewer(items: profile.photos + profile.videos, selection: item.id)
        }
        .sheet(isPresented: $showRequestSheet) {
            ConnectionRequestSheet(profile: profile)
                .presentationDetents([.medium])
                .presentationCornerRadius(Theme.Radius.xl)
        }
        .sheet(isPresented: $showReport) {
            ReportSheet(user: profile.ref) { dismiss() }
        }
        .confirmationDialog("Block \(profile.firstName)?", isPresented: $confirmBlock, titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                Task {
                    await model.block(profile.ref)
                    dismiss()
                }
            }
        } message: {
            Text("They won't be able to find you, message you or send you bottles. They won't be notified.")
        }
    }

    private func isVisible(_ category: ProfileCategory) -> Bool {
        isPreview ? profile.visibility(of: category) == .public
                  : profile.visibility(of: category) == .public || revealed.contains(category)
    }

    // MARK: Sections

    private var gallery: some View {
        let photos = isVisible(.media) || profile.photos.count <= 1 ? profile.photos : Array(profile.photos.prefix(1))
        return TabView(selection: $page) {
            ForEach(Array(photos.enumerated()), id: \.element.id) { index, item in
                Button { viewerItem = item } label: {
                    MediaImage(item: item)
                }
                .buttonStyle(.plain)
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
        .frame(height: 480)
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [.clear, Theme.Palette.background], startPoint: .top, endPoint: .bottom)
                .frame(height: 80)
                .allowsHitTesting(false)
        }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(profile.firstName).font(.display(34, weight: .bold))
                Text("\(profile.age)").font(.display(28)).foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                if profile.isOnline {
                    Label("Online", systemImage: "circle.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.ui(12, weight: .semibold))
                        .foregroundStyle(Theme.Palette.online)
                        .imageScale(.small)
                } else {
                    Text("Active \(profile.lastActive.formatted(.relative(presentation: .named)))")
                        .font(.ui(12))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            .foregroundStyle(Theme.Palette.textPrimary)
            Text(showsLocation ? profile.locationLine : "\(profile.country.flag) \(profile.country.name)")
                .font(.ui(16, weight: .medium))
                .foregroundStyle(Theme.Palette.textSecondary)
            if !profile.status.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "quote.opening").font(.system(size: 11))
                    Text(profile.status)
                }
                .font(.ui(14))
                .foregroundStyle(Theme.Palette.accent)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(Theme.Palette.accentSoft))
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("About").font(.ui(13, weight: .semibold)).textCase(.uppercase).tracking(0.8)
                .foregroundStyle(Theme.Palette.textTertiary)
            Text(profile.bio)
                .font(.display(19, weight: .regular))
                .foregroundStyle(Theme.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var videos: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Videos").font(.ui(13, weight: .semibold)).textCase(.uppercase).tracking(0.8)
                .foregroundStyle(Theme.Palette.textTertiary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.m) {
                    ForEach(profile.videos) { video in
                        Button { viewerItem = video } label: {
                            MediaThumbnail(item: video).frame(width: 200, height: 130)
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            if isVisible(.basics) {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    if !profile.details.occupation.isEmpty {
                        InfoRow(icon: "briefcase", text: profile.details.occupation)
                    }
                    if !profile.languages.isEmpty {
                        InfoRow(icon: "character.bubble", text: profile.languages.joined(separator: " · "))
                    }
                }
                .cardStyle()
            }
            ForEach([ProfileCategory.interests, .hobbies, .music, .moviesBooks, .lifestyle, .personality, .additional]) { category in
                if isVisible(category), profile.hasContent(for: category) {
                    CategoryCard(category: category, items: profile.items(for: category))
                }
            }
        }
    }

    @ViewBuilder
    private var lockedCategories: some View {
        let locked = ProfileCategory.allCases.filter {
            profile.visibility(of: $0) == .gradual && !isVisible($0) && profile.hasContent(for: $0)
        }
        if !locked.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                Label(isPreview ? "Shared only in chats" : "Discover in conversation", systemImage: "lock")
                    .font(.ui(15, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(isPreview
                     ? "These categories stay private until you choose to reveal them to someone."
                     : "\(profile.firstName) shares these only when they feel ready.")
                    .font(.ui(13))
                    .foregroundStyle(Theme.Palette.textSecondary)
                FlowLayout {
                    ForEach(locked) { category in
                        ChipView(text: category.title, icon: category.icon, style: .outline)
                    }
                }
            }
            .padding(Theme.Spacing.l)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .foregroundStyle(Theme.Palette.textTertiary.opacity(0.6))
            )
        }
    }

    private var safetyFooter: some View {
        Label("Never send money or share financial details with someone you met online.", systemImage: "shield.lefthalf.filled")
            .font(.ui(12))
            .foregroundStyle(Theme.Palette.textTertiary)
    }

    @ViewBuilder
    private var connectBar: some View {
        let existing = model.conversations.first { $0.participant.id == profile.id }
        let pending = model.outgoingRequests[profile.id]
        Group {
            if let existing {
                Button {
                    model.openConversation(existing.id)
                } label: {
                    Label("Open conversation", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .buttonStyle(.primary)
            } else if let pending, pending.state == .pending {
                Label("Request sent · waiting for \(profile.firstName)", systemImage: "clock")
                    .font(.ui(15, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(Theme.Palette.surfaceMuted))
            } else {
                Button { showRequestSheet = true } label: {
                    Label("Send a connection request", systemImage: "paperplane.fill")
                }
                .buttonStyle(.primary)
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.m)
        .background(.ultraThinMaterial)
    }
}

struct CategoryCard: View {
    let category: ProfileCategory
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Label(category.title, systemImage: category.icon)
                .font(.ui(15, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
            FlowLayout {
                ForEach(items, id: \.self) { ChipView(text: $0) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

struct ConnectionRequestSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let profile: UserProfile
    @State private var note = ""
    @State private var isSending = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            HStack(spacing: Theme.Spacing.m) {
                AvatarView(profile: profile, size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect with \(profile.firstName)").font(.display(22, weight: .semibold))
                    Text("A short note makes a great first impression.")
                        .font(.ui(14)).foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            TextField("Say why you'd like to connect (optional)", text: $note, axis: .vertical)
                .lineLimit(3...5)
                .font(.ui(16))
                .padding(14)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.medium).fill(Theme.Palette.surfaceMuted))
            Spacer()
            Button {
                isSending = true
                Task {
                    let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
                    if case .rejected(let reason) = model.services.moderation.review(text: text) {
                        model.showToast(reason, icon: "exclamationmark.shield", style: .warning)
                    } else {
                        await model.sendConnectionRequest(to: profile, note: text.isEmpty ? nil : text)
                        dismiss()
                    }
                    isSending = false
                }
            } label: {
                HStack {
                    if isSending { ProgressView().tint(.white) }
                    Text("Send request")
                }
            }
            .buttonStyle(.primary)
            .disabled(isSending)
        }
        .padding(Theme.Spacing.xl)
        .screenBackground()
    }
}
