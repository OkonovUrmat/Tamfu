import SwiftUI

enum ProfileRoute: Hashable {
    case edit, categories, settings, privacy, discovery, notifications, blocked, reported, account, preview
}

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @State private var path: [ProfileRoute] = []
    @State private var viewerItem: MediaItem?

    private var user: UserProfile { model.currentUser }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    hero
                    statsRow
                    if !user.bio.isEmpty {
                        Text(user.bio)
                            .font(.display(19, weight: .regular))
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    gallery
                    infoCards
                    menu
                    TabBarSpacer()
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }
            .screenBackground()
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { path.append(.settings) } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
            }
            .navigationDestination(for: ProfileRoute.self) { route in
                destination(route)
            }
            .fullScreenCover(item: $viewerItem) { item in
                MediaViewer(items: user.photos + user.videos, selection: item.id)
            }
            .onChange(of: path) { _, newValue in
                model.setTabBar(hidden: !newValue.isEmpty, for: .profile)
            }
        }
    }

    @ViewBuilder
    private func destination(_ route: ProfileRoute) -> some View {
        switch route {
        case .edit: EditProfileView()
        case .categories: CategoryVisibilityView()
        case .settings: SettingsView(path: $path)
        case .privacy: PrivacySettingsView()
        case .discovery: DiscoveryPreferencesView()
        case .notifications: NotificationSettingsView()
        case .blocked: BlockedUsersView()
        case .reported: ReportedUsersView()
        case .account: AccountSettingsView()
        case .preview: ProfileDetailView(profile: model.currentUser, isPreview: true)
        }
    }

    // MARK: Sections

    private var hero: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.l) {
            AvatarView(profile: user, size: 92, showsOnline: false)
                .overlay(Circle().strokeBorder(Theme.Gradients.accent, lineWidth: 3).padding(-5))
                .padding(5)
            VStack(alignment: .leading, spacing: 6) {
                Text("\(user.firstName), \(user.age)")
                    .font(.display(28, weight: .bold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(user.locationLine)
                    .font(.ui(15))
                    .foregroundStyle(Theme.Palette.textSecondary)
                if !user.status.isEmpty {
                    Text(user.status)
                        .font(.ui(13, weight: .medium))
                        .foregroundStyle(Theme.Palette.accent)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Theme.Palette.accentSoft))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, Theme.Spacing.s)
    }

    private var statsRow: some View {
        VStack(spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.m) {
                stat("\(model.sentBottles.count)", "Bottles thrown")
                stat("\(model.conversations.count)", "Conversations")
                stat("\(Set(model.conversations.map(\.participant.country)).count)", "Countries")
            }
            HStack(spacing: Theme.Spacing.m) {
                Button { path.append(.edit) } label: { Label("Edit profile", systemImage: "pencil") }
                    .buttonStyle(SecondaryButtonStyle())
                Button { path.append(.preview) } label: { Label("Preview", systemImage: "eye") }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.display(22, weight: .bold)).foregroundStyle(Theme.Palette.textPrimary)
            Text(label).font(.ui(11.5)).foregroundStyle(Theme.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.m)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous).fill(Theme.Palette.surface))
    }

    private var gallery: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionHeader(title: "Photos & videos", subtitle: user.visibility(of: .media).title,
                          action: (title: "Manage", handler: { path.append(.edit) }))
            if user.photos.isEmpty && user.videos.isEmpty {
                Button { path.append(.edit) } label: {
                    Label("Add your first photo", systemImage: "plus")
                        .frame(maxWidth: .infinity, minHeight: 100)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.medium)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                }
                .foregroundStyle(Theme.Palette.accent)
            } else {
                let items = user.photos + user.videos
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                    ForEach(items) { item in
                        Button { viewerItem = item } label: {
                            MediaThumbnail(item: item, cornerRadius: 12)
                                .aspectRatio(0.8, contentMode: .fit)
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }
        }
    }

    private var infoCards: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionHeader(title: "About me", subtitle: "Tap categories to control who sees what",
                          action: (title: "Visibility", handler: { path.append(.categories) }))
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                if !user.details.occupation.isEmpty { InfoRow(icon: "briefcase", text: user.details.occupation) }
                if !user.languages.isEmpty { InfoRow(icon: "character.bubble", text: user.languages.joined(separator: " · ")) }
            }
            .cardStyle()
            ForEach([ProfileCategory.interests, .hobbies, .music, .moviesBooks, .lifestyle, .personality]) { category in
                if user.hasContent(for: category) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                        HStack {
                            Label(category.title, systemImage: category.icon)
                                .font(.ui(15, weight: .semibold))
                            Spacer()
                            Label(user.visibility(of: category).title, systemImage: user.visibility(of: category).icon)
                                .font(.ui(11, weight: .semibold))
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                        FlowLayout {
                            ForEach(user.items(for: category), id: \.self) { ChipView(text: $0) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                }
            }
        }
    }

    private var menu: some View {
        VStack(spacing: 0) {
            menuRow("person.crop.rectangle.stack", "Profile categories", "Public, hidden or revealed in chats", .categories)
            Divider().padding(.leading, 52)
            menuRow("hand.raised", "Privacy & safety", "Requests, visibility, message limits", .privacy)
            Divider().padding(.leading, 52)
            menuRow("gearshape", "All settings", nil, .settings)
        }
        .cardStyle(padding: 0)
    }

    private func menuRow(_ icon: String, _ title: String, _ subtitle: String?, _ route: ProfileRoute) -> some View {
        Button { path.append(route) } label: {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.Palette.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.ui(15, weight: .medium)).foregroundStyle(Theme.Palette.textPrimary)
                    if let subtitle {
                        Text(subtitle).font(.ui(12)).foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Palette.textTertiary)
            }
            .padding(Theme.Spacing.l)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
