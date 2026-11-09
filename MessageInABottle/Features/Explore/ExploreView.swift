import SwiftUI

struct ExploreView: View {
    @Environment(AppModel.self) private var model
    @State private var vm = ExploreViewModel()
    @State private var showFilters = false
    @State private var path: [UserProfile] = []

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: Theme.Spacing.l) {
                header
                ZStack {
                    if vm.isLoading && !vm.hasLoaded {
                        loadingState
                    } else if vm.candidates.isEmpty {
                        emptyState
                    } else {
                        cardStack
                    }
                }
                .frame(maxHeight: .infinity)
                actionBar
                TabBarSpacer()
            }
            .padding(.horizontal, Theme.Spacing.l)
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UserProfile.self) { profile in
                ProfileDetailView(profile: profile)
            }
            .sheet(isPresented: $showFilters) {
                FiltersView(filters: $vm.filters) {
                    Task { await vm.load(using: model) }
                }
                .presentationDetents([.large])
                .presentationCornerRadius(Theme.Radius.xl)
            }
            .overlay {
                if let match = vm.match {
                    MatchOverlay(profile: match) {
                        vm.match = nil
                        model.startConversationFromMatch(with: match)
                    } onDismiss: {
                        withAnimation { vm.match = nil }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 1.05)))
                }
            }
            .task {
                if !vm.hasLoaded { await vm.load(using: model) }
            }
            .onChange(of: path) { _, newValue in
                model.setTabBar(hidden: !newValue.isEmpty, for: .explore)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Explore")
                    .font(.display(32, weight: .bold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(model.settings.privacy.appearInDiscovery ? "People from every shore" : "You're hidden from discovery")
                    .font(.ui(14))
                    .foregroundStyle(model.settings.privacy.appearInDiscovery ? Theme.Palette.textSecondary : Theme.Palette.warning)
            }
            Spacer()
            Button { showFilters = true } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(CircleIconButtonStyle(size: 44))
            .overlay(alignment: .topTrailing) {
                if vm.filters.activeCount > 0 {
                    Text("\(vm.filters.activeCount)")
                        .font(.roundedUI(11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Theme.Palette.accent))
                        .offset(x: 3, y: -3)
                }
            }
            .accessibilityLabel("Filters")
        }
        .padding(.top, Theme.Spacing.s)
    }

    private var cardStack: some View {
        ZStack {
            ForEach(Array(vm.candidates.prefix(3).enumerated().reversed()), id: \.element.id) { index, profile in
                SwipeCardView(
                    profile: profile,
                    isTop: index == 0,
                    programmaticSwipe: index == 0 ? vm.programmaticSwipe : nil,
                    onSwipe: { direction in vm.swipe(profile, direction, using: model) },
                    onTap: { path.append(profile) }
                )
                .scaleEffect(1 - CGFloat(index) * 0.05)
                .offset(y: CGFloat(index) * 14)
                .opacity(index == 2 ? 0.6 : 1)
                .allowsHitTesting(index == 0)
                .zIndex(Double(3 - index))
            }
        }
        .animation(Theme.Motion.snappy, value: vm.candidates.map(\.id))
    }

    private var actionBar: some View {
        HStack(spacing: Theme.Spacing.xl) {
            Button { vm.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .buttonStyle(CircleIconButtonStyle(size: 48, foreground: Theme.Palette.warning))
                .disabled(vm.lastSwiped == nil)
                .opacity(vm.lastSwiped == nil ? 0.4 : 1)
                .accessibilityLabel("Undo")

            Button { vm.trigger(.left) } label: { Image(systemName: "xmark") }
                .buttonStyle(CircleIconButtonStyle(size: 64, foreground: Theme.Palette.danger))
                .accessibilityLabel("Skip")
                .disabled(vm.candidates.isEmpty)

            Button { vm.trigger(.right) } label: { Image(systemName: "heart.fill") }
                .buttonStyle(CircleIconButtonStyle(size: 64, background: Theme.Palette.accent, foreground: .white))
                .accessibilityLabel("Interested")
                .disabled(vm.candidates.isEmpty)

            Button {
                if let top = vm.top { path.append(top) }
            } label: { Image(systemName: "info") }
                .buttonStyle(CircleIconButtonStyle(size: 48, foreground: Theme.Palette.accent))
                .accessibilityLabel("Open profile")
                .disabled(vm.candidates.isEmpty)
        }
    }

    private var loadingState: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
            .fill(Theme.Palette.surfaceMuted)
            .overlay(ProgressView())
            .redacted(reason: .placeholder)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.l) {
            BottleIllustration(size: 120, showsScroll: false)
                .floating(amplitude: 6, rotation: 10)
                .opacity(0.8)
            Text("You've met everyone on this shore")
                .font(.display(22, weight: .semibold))
                .multilineTextAlignment(.center)
            Text(vm.filters.activeCount > 0
                 ? "Try widening your filters to discover more people."
                 : "Check back later — new people wash up every day.")
                .font(.ui(15))
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
            HStack {
                if vm.filters.activeCount > 0 {
                    Button("Reset filters") {
                        vm.filters = DiscoveryFilters()
                        Task { await vm.load(using: model) }
                    }
                    .buttonStyle(SecondaryButtonStyle(fullWidth: false))
                }
                Button("Refresh") { Task { await vm.load(using: model) } }
                    .buttonStyle(PrimaryButtonStyle(fullWidth: false))
            }
        }
        .padding(Theme.Spacing.xl)
    }
}

// MARK: - Swipe card

struct SwipeCardView: View {
    let profile: UserProfile
    var isTop: Bool
    var programmaticSwipe: SwipeDirection?
    var onSwipe: (SwipeDirection) -> Void
    var onTap: () -> Void

    @State private var offset: CGSize = .zero
    @State private var photoIndex = 0
    private let threshold: CGFloat = 120

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                photo
                Theme.Gradients.cardScrim
                info
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
            .overlay(alignment: .top) { photoIndicators }
            .overlay(alignment: .topLeading) { stamp("INTERESTED", color: Theme.Palette.turquoise, angle: -12).opacity(Double(max(0, offset.width / threshold))) }
            .overlay(alignment: .topTrailing) { stamp("SKIP", color: Theme.Palette.coral, angle: 12).opacity(Double(max(0, -offset.width / threshold))) }
            .shadow(color: Theme.Palette.deepOcean.opacity(isTop ? 0.18 : 0.05), radius: 24, x: 0, y: 14)
            .offset(offset)
            .rotationEffect(.degrees(Double(offset.width / 22)), anchor: .bottom)
            .gesture(drag(width: geo.size.width))
            .onTapGesture(coordinateSpace: .local) { location in
                // Left/right thirds of the photo area page through photos; the rest opens the profile.
                if location.y < geo.size.height * 0.6, photos.count > 1 {
                    if location.x < geo.size.width * 0.3 {
                        withAnimation(.easeOut(duration: 0.15)) { photoIndex = max(0, photoIndex - 1) }
                        return
                    } else if location.x > geo.size.width * 0.7 {
                        withAnimation(.easeOut(duration: 0.15)) { photoIndex = min(photos.count - 1, photoIndex + 1) }
                        return
                    }
                }
                onTap()
            }
            .onChange(of: programmaticSwipe) { _, direction in
                guard let direction else { return }
                flyOut(direction, width: geo.size.width)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: abs(offset.width) > threshold)
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Interested") { onSwipe(.right) }
        .accessibilityAction(named: "Skip") { onSwipe(.left) }
        .accessibilityAction(named: "Open profile") { onTap() }
    }

    /// Only categories the person made public appear on their card.
    private var publicTags: [String] {
        var tags: [String] = []
        if profile.visibility(of: .interests) == .public { tags += profile.interests }
        if profile.visibility(of: .hobbies) == .public { tags += profile.hobbies }
        return Array(tags.prefix(4))
    }

    private var photos: [MediaItem] {
        profile.visibility(of: .media) == .public ? profile.photos : Array(profile.photos.prefix(1))
    }

    @ViewBuilder
    private var photo: some View {
        if photos.indices.contains(photoIndex) {
            MediaImage(item: photos[photoIndex])
        } else {
            Theme.Gradients.seeded(profile.avatarSeed)
        }
    }

    private var photoIndicators: some View {
        HStack(spacing: 4) {
            if photos.count > 1 {
                ForEach(photos.indices, id: \.self) { i in
                    Capsule()
                        .fill(.white.opacity(i == photoIndex ? 0.95 : 0.35))
                        .frame(height: 3)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.m)
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if !profile.status.isEmpty {
                ChipView(text: profile.status, style: .onDark)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(profile.firstName)
                    .font(.display(32, weight: .bold))
                Text("\(profile.age)")
                    .font(.display(26, weight: .regular))
                    .opacity(0.9)
                if profile.isOnline {
                    Circle().fill(Theme.Palette.online).frame(width: 9, height: 9)
                }
            }
            Text(profile.locationLine)
                .font(.ui(15, weight: .medium))
                .opacity(0.9)
            Text(profile.bio)
                .font(.ui(15))
                .lineLimit(2)
                .opacity(0.85)
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(publicTags, id: \.self) { tag in
                    ChipView(text: tag, style: .onDark)
                }
                if !profile.videos.isEmpty && profile.visibility(of: .media) == .public {
                    ChipView(text: "\(profile.videos.count) video", icon: "play.fill", style: .onDark)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(Theme.Spacing.xl)
    }

    private func stamp(_ text: String, color: Color, angle: Double) -> some View {
        Text(text)
            .font(.roundedUI(24, weight: .heavy))
            .tracking(2)
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color, lineWidth: 3))
            .rotationEffect(.degrees(angle))
            .padding(28)
    }

    private func drag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                offset = CGSize(width: value.translation.width, height: value.translation.height * 0.3)
            }
            .onEnded { value in
                let predicted = value.predictedEndTranslation.width
                if value.translation.width > threshold || predicted > threshold * 2.2 {
                    flyOut(.right, width: width)
                } else if value.translation.width < -threshold || predicted < -threshold * 2.2 {
                    flyOut(.left, width: width)
                } else {
                    withAnimation(Theme.Motion.bouncy) { offset = .zero }
                }
            }
    }

    private func flyOut(_ direction: SwipeDirection, width: CGFloat) {
        let x = (direction == .right ? 1 : -1) * (width * 1.5)
        withAnimation(.easeIn(duration: 0.28)) {
            offset = CGSize(width: x, height: offset.height + 40)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            onSwipe(direction)
        }
    }
}

// MARK: - Match

struct MatchOverlay: View {
    let profile: UserProfile
    var onMessage: () -> Void
    var onDismiss: () -> Void
    @Environment(AppModel.self) private var model
    @State private var appear = false

    var body: some View {
        ZStack {
            Theme.Gradients.ocean.opacity(0.97).ignoresSafeArea()
            VStack(spacing: Theme.Spacing.xl) {
                Spacer()
                Text("Two bottles,\none current")
                    .font(.display(38, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                Text("You and \(profile.firstName) are both interested. Say hello before the tide turns.")
                    .font(.ui(16))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.8))
                HStack(spacing: -24) {
                    AvatarView(profile: model.currentUser, size: 120, showsOnline: false)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                        .rotationEffect(.degrees(appear ? -8 : 0))
                        .offset(x: appear ? 0 : -120)
                    AvatarView(profile: profile, size: 120, showsOnline: false)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                        .rotationEffect(.degrees(appear ? 8 : 0))
                        .offset(x: appear ? 0 : 120)
                }
                .padding(.vertical, Theme.Spacing.xl)
                Spacer()
                Button("Send a message", action: onMessage)
                    .buttonStyle(.primary)
                Button("Keep exploring", action: onDismiss)
                    .font(.ui(16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(Theme.Spacing.xl)
        }
        .sensoryFeedback(.success, trigger: appear)
        .onAppear { withAnimation(Theme.Motion.bouncy.delay(0.1)) { appear = true } }
    }
}
