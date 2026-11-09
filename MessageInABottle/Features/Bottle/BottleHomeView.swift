import SwiftUI

struct BottleHomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showCompose = false
    @State private var showShore = false
    @State private var showHistory = false
    @State private var bottleTapCount = 0
    @State private var isCheckingShore = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Gradients.ocean.ignoresSafeArea()
                StarField().ignoresSafeArea().opacity(0.6)

                VStack {
                    Spacer()
                    OceanWaves(height: 200, tint: Theme.Palette.seafoam)
                }
                .ignoresSafeArea()

                VStack(spacing: Theme.Spacing.l) {
                    header
                    Spacer(minLength: 0)
                    bottle
                    Spacer(minLength: 0)
                    if !model.shore.isEmpty { shoreBanner }
                    quotaCard
                    sendButton
                    TabBarSpacer()
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showCompose) {
                ComposeBottleView()
            }
            .sheet(isPresented: $showShore) {
                ShoreSheet()
                    .presentationDetents([.medium, .large])
                    .presentationCornerRadius(Theme.Radius.xl)
            }
            .sheet(isPresented: $showHistory) {
                SentBottlesSheet()
                    .presentationDetents([.medium, .large])
                    .presentationCornerRadius(Theme.Radius.xl)
            }
            .task { await model.refreshBottles() }
        }
    }

    // MARK: Sections

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(greeting), \(model.currentUser.firstName)")
                    .font(.ui(14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Text("The ocean is listening")
                    .font(.display(26, weight: .bold))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button { showHistory = true } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .buttonStyle(CircleIconButtonStyle(size: 42, background: .white.opacity(0.12), foreground: .white))
            .accessibilityLabel("Your sent bottles")

            Button { showShore = true } label: {
                Image(systemName: "beach.umbrella")
            }
            .buttonStyle(CircleIconButtonStyle(size: 42, background: .white.opacity(0.12), foreground: .white))
            .overlay(alignment: .topTrailing) {
                if !model.shore.isEmpty {
                    Text("\(model.shore.count)")
                        .font(.roundedUI(11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Theme.Palette.coral))
                        .offset(x: 4, y: -4)
                }
            }
            .accessibilityLabel("Bottles on your shore")
        }
        .padding(.top, Theme.Spacing.s)
    }

    private var bottle: some View {
        Button {
            bottleTapCount += 1
            showCompose = true
        } label: {
            VStack(spacing: Theme.Spacing.l) {
                BottleIllustration(size: 210, glow: true)
                    .floating(amplitude: 12, rotation: 5)
                    .phaseAnimator([false, true], trigger: bottleTapCount) { view, phase in
                        view.scaleEffect(phase ? 1.08 : 1)
                    } animation: { _ in Theme.Motion.bouncy }
                Text("Write something. Seal it. Let it drift.")
                    .font(.display(17, weight: .regular))
                    .italic()
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: bottleTapCount)
        .accessibilityLabel("Write a new bottle")
    }

    private var shoreBanner: some View {
        Button {
            if model.shore.count == 1, let first = model.shore.first {
                model.open(first)
            } else {
                showShore = true
            }
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: "sparkles")
                    .symbolEffect(.pulse)
                Text(model.shore.count == 1 ? "A bottle washed up on your shore" : "\(model.shore.count) bottles washed up on your shore")
                    .font(.ui(14, weight: .semibold))
                Spacer()
                Text("Open")
                    .font(.ui(14, weight: .bold))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(.white))
                    .foregroundStyle(Theme.Palette.deepOcean)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.m)
            .background(Capsule().fill(Theme.Palette.coral.opacity(0.9)))
        }
        .buttonStyle(.pressable)
        .transition(.scale.combined(with: .opacity))
    }

    private var quotaCard: some View {
        HStack(spacing: Theme.Spacing.l) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(model.quota.sentToday) of \(model.quota.limit) bottles sent today")
                    .font(.ui(12, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.6))
                HStack(spacing: 5) {
                    ForEach(0..<model.quota.limit, id: \.self) { i in
                        Capsule()
                            .fill(i < model.quota.sentToday ? Theme.Palette.seafoam : .white.opacity(0.18))
                            .frame(height: 6)
                    }
                }
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(model.quota.remaining)")
                    .font(.display(26, weight: .bold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text("remaining")
                    .font(.ui(11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(Theme.Spacing.l)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .fill(.white.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(model.quota.sentToday) messages sent today, \(model.quota.remaining) remaining")
    }

    private var sendButton: some View {
        Button {
            showCompose = true
        } label: {
            Label(model.quota.remaining > 0 ? "Send a message to the world" : "Come back tomorrow",
                  systemImage: model.quota.remaining > 0 ? "paperplane.fill" : "moon.stars")
        }
        .buttonStyle(.primary)
        .disabled(model.quota.remaining == 0)
    }
}

/// Very subtle twinkling dots in the night sky.
struct StarField: View {
    private struct Star { let x, y, size: CGFloat; let phase: Double }

    @State private var stars: [Star] = (0..<40).map { _ in
        Star(x: .random(in: 0...1), y: .random(in: 0...0.45), size: .random(in: 1...2.2), phase: .random(in: 0...6))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 15)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                for star in stars {
                    let alpha = 0.35 + 0.35 * sin(t * 0.8 + star.phase)
                    let rect = CGRect(x: star.x * size.width, y: star.y * size.height, width: star.size, height: star.size)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
