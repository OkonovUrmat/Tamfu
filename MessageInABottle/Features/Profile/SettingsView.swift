import SwiftUI

extension AppModel {
    /// Binding that persists the setting on every change.
    func setting<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { value in self.updateSettings { $0[keyPath: keyPath] = value } }
        )
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Binding var path: [ProfileRoute]
    @State private var confirmLogout = false
    @State private var isLoggingOut = false

    var body: some View {
        List {
            Section {
                row("person.crop.circle", "Account", .account)
                row("person.crop.rectangle.stack", "Profile categories", .categories)
            }
            Section("Safety") {
                row("hand.raised", "Privacy settings", .privacy)
                row("tray.and.arrow.down", "Incoming message limits", .privacy,
                    detail: "\(model.settings.privacy.dailyIncomingLimit)/day")
                row("person.crop.circle.badge.xmark", "Blocked users", .blocked,
                    detail: model.blockedUsers.isEmpty ? nil : "\(model.blockedUsers.count)")
                row("exclamationmark.bubble", "Reported users", .reported,
                    detail: model.reports.isEmpty ? nil : "\(model.reports.count)")
            }
            Section("Experience") {
                row("safari", "Discovery preferences", .discovery)
                row("bell.badge", "Notifications", .notifications)
                Picker(selection: model.setting(\.language)) {
                    ForEach(AppLanguage.allCases) { Text($0.rawValue).tag($0) }
                } label: {
                    Label("Language", systemImage: "globe")
                }
                Picker(selection: model.setting(\.theme)) {
                    ForEach(AppTheme.allCases) { Text($0.title).tag($0) }
                } label: {
                    Label("Theme", systemImage: "circle.lefthalf.filled")
                }
            }
            Section {
                Button(role: .destructive) { confirmLogout = true } label: {
                    HStack {
                        Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                        if isLoggingOut { Spacer(); ProgressView() }
                    }
                }
            } footer: {
                VStack(spacing: 4) {
                    Text("Message in a Bottle · v1.0 (mock backend)")
                    Text("Made with care for kind strangers 🌊")
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.l)
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Settings")
        .confirmationDialog("Log out of Message in a Bottle?", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("Log out", role: .destructive) {
                isLoggingOut = true
                Task { await model.signOut() }
            }
        }
    }

    private func row(_ icon: String, _ title: String, _ route: ProfileRoute, detail: String? = nil) -> some View {
        NavigationLink(value: route) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                if let detail {
                    Text(detail).foregroundStyle(Theme.Palette.textSecondary)
                }
            }
        }
    }
}

// MARK: - Privacy

struct PrivacySettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                Picker("Who can send connection requests", selection: model.setting(\.privacy.connectionRequestsFrom)) {
                    ForEach(Audience.allCases.filter { $0 != .connections }) { Text($0.title).tag($0) }
                }
                Picker("Who can see my profile", selection: model.setting(\.privacy.profileVisibleTo)) {
                    ForEach(Audience.allCases.filter { $0 != .sharedInterests }) { Text($0.title).tag($0) }
                }
            } header: {
                Text("Who can reach me")
            }

            Section {
                Toggle("Receive bottles", isOn: model.setting(\.privacy.receiveBottles))
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    Text("Maximum incoming bottles per day")
                    Picker("Daily limit", selection: model.setting(\.privacy.dailyIncomingLimit)) {
                        ForEach(PrivacySettings.incomingLimitOptions, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, 4)
                .disabled(!model.settings.privacy.receiveBottles)
            } header: {
                Text("Incoming messages")
            } footer: {
                Text("Once you reach your limit, bottles skip your shore and drift to someone else. You'll never be overwhelmed.")
            }

            Section {
                Toggle("Appear in global discovery", isOn: model.setting(\.privacy.appearInDiscovery))
                Toggle("Show my city", isOn: model.setting(\.privacy.showLocation))
                Toggle("Show when I'm online", isOn: model.setting(\.privacy.showOnlineStatus))
            } header: {
                Text("Visibility")
            } footer: {
                Text("When your city is hidden, people only see your country.")
            }

            Section("Safety tools") {
                Label("Every bottle and photo is screened before delivery", systemImage: "checkmark.shield")
                Label("Links, phone numbers and spam are blocked automatically", systemImage: "link.badge.plus")
                Label("Only adults (18+) can use the app", systemImage: "person.badge.shield.checkmark")
            }
            .font(.ui(14))
            .foregroundStyle(Theme.Palette.textSecondary)
        }
        .tint(Theme.Palette.accent)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Privacy")
    }
}

// MARK: - Discovery preferences

struct DiscoveryPreferencesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    HStack {
                        Text("Age range")
                        Spacer()
                        Text("\(model.settings.discovery.minAge) – \(model.settings.discovery.maxAge)")
                            .foregroundStyle(Theme.Palette.accent)
                    }
                    RangeSlider(lower: model.setting(\.discovery.minAge),
                                upper: model.setting(\.discovery.maxAge),
                                bounds: 18...80)
                }
                .padding(.vertical, 6)
            } header: {
                Text("Who I'd like to meet")
            } footer: {
                Text("Applies to Explore and to which bottles reach you. Everyone on Message in a Bottle is 18+.")
            }

            Section {
                Toggle("Receive bottles from anywhere", isOn: model.setting(\.discovery.bottlesFromAnywhere))
            } footer: {
                Text("Turn off to prefer bottles from people who speak your languages.")
            }

            Section("Preferred languages") {
                ChipPicker(options: MockData.allLanguages,
                           selection: Binding(
                            get: { Set(model.settings.discovery.preferredLanguages) },
                            set: { value in model.updateSettings { $0.discovery.preferredLanguages = Array(value).sorted() } }))
                .padding(.vertical, 6)
            }
        }
        .tint(Theme.Palette.accent)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Discovery")
    }
}

// MARK: - Notifications

struct NotificationSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                Toggle("A bottle washes ashore", isOn: model.setting(\.notifications.newBottles))
                Toggle("Someone finds my bottle", isOn: model.setting(\.notifications.bottleFound))
                Toggle("New messages", isOn: model.setting(\.notifications.messages))
                Toggle("Connection requests", isOn: model.setting(\.notifications.connectionRequests))
                Toggle("Game invites", isOn: model.setting(\.notifications.gameInvites))
            } footer: {
                Text("Push notifications will be delivered once the backend is connected.")
            }
        }
        .tint(Theme.Palette.accent)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Notifications")
    }
}

// MARK: - Profile categories

struct CategoryVisibilityView: View {
    @Environment(AppModel.self) private var model
    @State private var isSaving = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    ForEach(CategoryVisibility.allCases) { v in
                        Label {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(v.title).font(.ui(14, weight: .semibold))
                                Text(v.explanation).font(.ui(12)).foregroundStyle(Theme.Palette.textSecondary)
                            }
                        } icon: {
                            Image(systemName: v.icon).foregroundStyle(Theme.Palette.accent)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Categories") {
                ForEach(ProfileCategory.allCases) { category in
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        HStack {
                            Label(category.title, systemImage: category.icon)
                                .font(.ui(15, weight: .medium))
                            Spacer()
                            if !model.currentUser.hasContent(for: category) {
                                Text("Empty").font(.ui(11)).foregroundStyle(Theme.Palette.textTertiary)
                            }
                        }
                        Picker(category.title, selection: binding(for: category)) {
                            ForEach(CategoryVisibility.allCases) { v in
                                Text(v.title).tag(v)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Profile categories")
    }

    private func binding(for category: ProfileCategory) -> Binding<CategoryVisibility> {
        Binding(
            get: { model.currentUser.visibility(of: category) },
            set: { value in
                var profile = model.currentUser
                profile.categoryVisibility[category] = value
                model.currentUser = profile
                Task { _ = try? await model.services.profile.save(profile) }
            }
        )
    }
}

// MARK: - Blocked / reported

struct BlockedUsersView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            if model.blockedUsers.isEmpty {
                ContentUnavailableView("No blocked users", systemImage: "hand.raised",
                                       description: Text("People you block can't see you, message you or send you bottles."))
                    .listRowBackground(Color.clear)
            }
            ForEach(model.blockedUsers) { user in
                HStack(spacing: Theme.Spacing.m) {
                    AvatarView(name: user.name, media: user.avatar, seed: user.avatarSeed, size: 40)
                    Text(user.name).font(.ui(15, weight: .medium))
                    Spacer()
                    Button("Unblock") { Task { await model.unblock(user) } }
                        .buttonStyle(.bordered)
                        .tint(Theme.Palette.accent)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Blocked users")
    }
}

struct ReportedUsersView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            if model.reports.isEmpty {
                ContentUnavailableView("No reports", systemImage: "checkmark.shield",
                                       description: Text("Reports you submit appear here with their status."))
                    .listRowBackground(Color.clear)
            }
            ForEach(model.reports) { report in
                HStack(spacing: Theme.Spacing.m) {
                    AvatarView(name: report.user.name, media: report.user.avatar, seed: report.user.avatarSeed, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(report.user.name).font(.ui(15, weight: .medium))
                        Text(report.reason.rawValue).font(.ui(13)).foregroundStyle(Theme.Palette.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("In review")
                            .font(.ui(11, weight: .bold))
                            .foregroundStyle(Theme.Palette.warning)
                        Text(report.createdAt.chatTimestamp)
                            .font(.ui(11))
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Reported users")
    }
}

// MARK: - Account

struct AccountSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var showDelete = false
    @State private var confirmation = ""
    @State private var isDeleting = false

    var body: some View {
        Form {
            Section("Account") {
                LabeledContent("Name", value: model.currentUser.name)
                LabeledContent("Member ID", value: String(model.currentUser.id.uuidString.prefix(8)))
                LabeledContent("Birthday", value: model.currentUser.birthDate.formatted(date: .long, time: .omitted))
                LabeledContent("Sign-in", value: "Demo account")
            }

            Section {
                Button("Download my data") {
                    model.showToast("Your data export will be emailed to you within 48 hours.", icon: "arrow.down.doc", style: .success)
                }
            } footer: {
                Text("Get a copy of your profile, messages and bottles.")
            }

            Section {
                Button("Delete account", role: .destructive) { showDelete = true }
            } footer: {
                Text("Permanently deletes your profile, conversations, bottles and media. This can't be undone.")
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Account")
        .sheet(isPresented: $showDelete) {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.Palette.danger)
                Text("Delete your account?")
                    .font(.display(26, weight: .bold))
                Text("All your conversations, revealed information and bottles at sea will be deleted forever. Type DELETE to confirm.")
                    .font(.ui(15))
                    .foregroundStyle(Theme.Palette.textSecondary)
                TextField("DELETE", text: $confirmation)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.small).fill(Theme.Palette.surfaceMuted))
                Spacer()
                Button {
                    isDeleting = true
                    Task {
                        await model.deleteAccount()
                        isDeleting = false
                        showDelete = false
                    }
                } label: {
                    HStack {
                        if isDeleting { ProgressView().tint(.white) }
                        Text("Delete permanently")
                    }
                    .font(.ui(17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(confirmation == "DELETE" ? Theme.Palette.danger : Theme.Palette.textTertiary.opacity(0.4)))
                }
                .disabled(confirmation != "DELETE" || isDeleting)
                Button("Cancel") { showDelete = false }
                    .frame(maxWidth: .infinity)
                    .font(.ui(16, weight: .medium))
            }
            .padding(Theme.Spacing.xl)
            .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Report

struct ReportSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let user: UserRef
    var onComplete: () -> Void

    @State private var reason: ReportReason?
    @State private var details = ""
    @State private var alsoBlock = true
    @State private var isSending = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(ReportReason.allCases) { r in
                        Button {
                            reason = r
                        } label: {
                            HStack {
                                Text(r.rawValue).foregroundStyle(Theme.Palette.textPrimary)
                                Spacer()
                                if reason == r {
                                    Image(systemName: "checkmark").foregroundStyle(Theme.Palette.accent)
                                }
                            }
                        }
                    }
                } header: {
                    Text("What's wrong?")
                } footer: {
                    Text("\(user.name) won't know you reported them.")
                }
                Section("Details (optional)") {
                    TextField("Tell us more", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    Toggle("Also block \(user.name)", isOn: $alsoBlock)
                        .tint(Theme.Palette.accent)
                }
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if isSending {
                        ProgressView()
                    } else {
                        Button("Submit") {
                            guard let reason else { return }
                            isSending = true
                            Task {
                                await model.report(user, reason: reason, details: details, alsoBlock: alsoBlock)
                                dismiss()
                                onComplete()
                            }
                        }
                        .fontWeight(.semibold)
                        .disabled(reason == nil)
                    }
                }
            }
        }
    }
}
