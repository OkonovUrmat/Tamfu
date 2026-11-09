import SwiftUI

/// Opening a bottle: the scroll unrolls, revealing the message and a teaser
/// about the sender — never the full profile.
struct IncomingBottleView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let bottle: IncomingBottle

    @State private var isOpen = false
    @State private var isWorking = false
    @State private var skipping = false
    @State private var viewerItem: MediaItem?
    @State private var showReport = false

    private var teaser: SenderTeaser { bottle.teaser }

    var body: some View {
        ZStack {
            Theme.Gradients.ocean.ignoresSafeArea()
            VStack {
                Spacer()
                OceanWaves(height: 160, tint: Theme.Palette.seafoam)
            }
            .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.l) {
                topBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Theme.Spacing.l) {
                        if !isOpen {
                            sealedBottle
                        } else {
                            letter
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.3, anchor: .top).combined(with: .opacity),
                                    removal: .move(edge: .bottom).combined(with: .opacity)))
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.m)
                }
                if isOpen { actions.transition(.move(edge: .bottom).combined(with: .opacity)) }
            }
            .offset(y: skipping ? 900 : 0)
            .rotationEffect(.degrees(skipping ? 8 : 0))
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(Theme.Motion.gentle) { isOpen = true }
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: isOpen)
        .fullScreenCover(item: $viewerItem) { item in
            MediaViewer(items: bottle.message.media, selection: item.id)
        }
        .sheet(isPresented: $showReport) {
            ReportSheet(user: teaser.ref) {
                model.shore.removeAll { $0.id == bottle.id }
                dismiss()
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: { Image(systemName: "chevron.down") }
                .buttonStyle(CircleIconButtonStyle(size: 38, background: .white.opacity(0.14), foreground: .white))
            Spacer()
            Text("Washed ashore \(bottle.message.createdAt.formatted(.relative(presentation: .named)))")
                .font(.ui(13, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
            Spacer()
            Menu {
                Button(role: .destructive) { showReport = true } label: {
                    Label("Report bottle", systemImage: "exclamationmark.bubble")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.white.opacity(0.14)))
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.l)
    }

    private var sealedBottle: some View {
        VStack(spacing: Theme.Spacing.l) {
            BottleIllustration(size: 200, glow: true)
                .floating(amplitude: 8, rotation: 8, speed: 2)
            Text("Uncorking…")
                .font(.display(20))
                .italic()
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.top, 80)
    }

    private var letter: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            senderTeaser
            Divider().overlay(Color(hex: 0xC9B48C).opacity(0.4))

            if !bottle.message.text.isEmpty {
                Text(bottle.message.text)
                    .font(.display(22, weight: .regular))
                    .foregroundStyle(Color(hex: 0x2B2A26))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !bottle.message.media.isEmpty {
                ForEach(bottle.message.media) { item in
                    Button { viewerItem = item } label: {
                        MediaThumbnail(item: item, cornerRadius: Theme.Radius.medium)
                            .frame(height: 220)
                    }
                    .buttonStyle(.pressable)
                }
            }

            HStack {
                Spacer()
                Text("— \(teaser.nickname)")
                    .font(.display(17, weight: .regular))
                    .italic()
                    .foregroundStyle(Color(hex: 0x6B604C))
            }
        }
        .padding(Theme.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xFCF6E6), Color(hex: 0xF1E5C8)],
                                     startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.25), radius: 30, x: 0, y: 20)
        )
    }

    private var senderTeaser: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.m) {
                AvatarView(name: teaser.nickname, seed: teaser.avatarSeed, size: 48, isBlurred: true)
                    .overlay(Image(systemName: "questionmark").font(.system(size: 18, weight: .bold)).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(teaser.nickname) · \(teaser.ageBracket)")
                        .font(.ui(16, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x2B2A26))
                    Text("\(teaser.country.flag) \(teaser.city.map { "\($0), " } ?? "")\(teaser.country.name)")
                        .font(.ui(14))
                        .foregroundStyle(Color(hex: 0x6B604C))
                    if !teaser.languages.isEmpty {
                        Text("Speaks " + teaser.languages.joined(separator: ", "))
                            .font(.ui(12))
                            .foregroundStyle(Color(hex: 0x8C806A))
                    }
                }
                Spacer()
            }
            if !teaser.mood.isEmpty {
                Text("“\(teaser.mood)”")
                    .font(.ui(13))
                    .italic()
                    .foregroundStyle(Color(hex: 0x6B604C))
            }
        }
    }

    private var actions: some View {
        VStack(spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.m) {
                Button {
                    isWorking = true
                    withAnimation(.easeIn(duration: 0.5)) { skipping = true }
                    Task {
                        try? await Task.sleep(nanoseconds: 450_000_000)
                        await model.skip(bottle)
                        dismiss()
                    }
                } label: {
                    Label("Skip", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    isWorking = true
                    Task {
                        await model.accept(bottle)
                        isWorking = false
                    }
                } label: {
                    Label("Accept & reply", systemImage: "bubble.left.fill")
                }
                .buttonStyle(.primary)
            }
            .disabled(isWorking)
            Text("Skipping sends the bottle back to sea for someone else. The sender won't be notified.")
                .font(.ui(12))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.l)
    }
}

/// Top banner shown when a new bottle arrives.
struct BottleArrivalBanner: View {
    let bottle: IncomingBottle
    var onOpen: () -> Void
    @State private var wiggle = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: Theme.Spacing.m) {
                BottleIllustration(size: 44, showsScroll: false)
                    .rotationEffect(.degrees(wiggle ? 12 : -12))
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: wiggle)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("A bottle washed ashore")
                        .font(.ui(15, weight: .semibold))
                    Text("From \(bottle.teaser.country.flag) \(bottle.teaser.country.name) · tap to open")
                        .font(.ui(13))
                        .opacity(0.8)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .opacity(0.6)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .fill(Theme.Gradients.night)
                    .shadow(color: Theme.Palette.deepOcean.opacity(0.35), radius: 24, x: 0, y: 12)
            )
        }
        .buttonStyle(.pressable)
        .sensoryFeedback(.impact(weight: .light), trigger: bottle.id)
        .onAppear { wiggle = true }
    }
}

/// Bottles waiting on the user's shore.
struct ShoreSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var isChecking = false

    var body: some View {
        NavigationStack {
            List {
                if model.shore.isEmpty {
                    ContentUnavailableView("Your shore is quiet",
                                           systemImage: "beach.umbrella",
                                           description: Text("New bottles arrive throughout the day. You'll receive at most \(model.settings.privacy.dailyIncomingLimit) per day."))
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(model.shore) { bottle in
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { model.open(bottle) }
                        } label: {
                            HStack(spacing: Theme.Spacing.m) {
                                BottleIllustration(size: 46, showsScroll: true)
                                    .frame(width: 34)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(bottle.teaser.nickname) from \(bottle.teaser.country.flag) \(bottle.teaser.country.name)")
                                        .font(.ui(15, weight: .semibold))
                                        .foregroundStyle(Theme.Palette.textPrimary)
                                    Text(bottle.message.media.isEmpty ? "Sealed message" : "Sealed message · \(bottle.message.media.count) attachment\(bottle.message.media.count > 1 ? "s" : "")")
                                        .font(.ui(13))
                                        .foregroundStyle(Theme.Palette.textSecondary)
                                }
                                Spacer()
                                Text(bottle.receivedAt.formatted(date: .omitted, time: .shortened))
                                    .font(.ui(12))
                                    .foregroundStyle(Theme.Palette.textTertiary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("On your shore")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button {
                    isChecking = true
                    Task {
                        await model.checkShore()
                        isChecking = false
                    }
                } label: {
                    HStack {
                        if isChecking { ProgressView().tint(.white) }
                        Text(isChecking ? "Looking at the waves…" : "Walk along the shore")
                    }
                }
                .buttonStyle(.primary)
                .disabled(isChecking)
                .padding()
            }
        }
    }
}

/// History of the user's own bottles.
struct SentBottlesSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
                if model.sentBottles.isEmpty {
                    ContentUnavailableView("No bottles yet",
                                           systemImage: "waterbottle",
                                           description: Text("Bottles you throw will appear here with their journey."))
                        .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(model.sentBottles) { bottle in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(bottle.text.isEmpty ? "📷 Media bottle" : bottle.text)
                                    .font(.ui(15))
                                    .lineLimit(2)
                                    .foregroundStyle(Theme.Palette.textPrimary)
                                HStack(spacing: 8) {
                                    Label(statusText(bottle), systemImage: bottle.status.icon)
                                        .font(.ui(12, weight: .semibold))
                                        .foregroundStyle(color(for: bottle.status))
                                    Spacer()
                                    Text(bottle.createdAt.formatted(.relative(presentation: .named)))
                                        .font(.ui(12))
                                        .foregroundStyle(Theme.Palette.textTertiary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } footer: {
                        Text("Unanswered bottles sink after \(Int(BottleRules.lifetime / 3600)) hours or \(BottleRules.maxDeliveryAttempts) skips.")
                    }
                }
            }
            .navigationTitle("Your bottles")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await model.refreshBottles() }
            .task { await model.refreshBottles() }
        }
    }

    private func statusText(_ bottle: BottleMessage) -> String {
        switch bottle.status {
        case .accepted:
            if let c = bottle.foundIn { return "Found in \(c.flag) \(c.name)" }
            return "Found"
        case .delivered: return "Washed ashore · waiting for an answer"
        case .drifting: return bottle.deliveryAttempts > 0 ? "Drifting again · \(bottle.deliveryAttempts) shores so far" : "Drifting"
        case .expired: return "Sank quietly"
        }
    }

    private func color(for status: BottleStatus) -> Color {
        switch status {
        case .accepted: return Theme.Palette.success
        case .delivered: return Theme.Palette.accent
        case .drifting: return Theme.Palette.textSecondary
        case .expired: return Theme.Palette.textTertiary
        }
    }
}
