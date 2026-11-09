import SwiftUI

/// Game picker + per-game setup. Each game's setup is its own view so new
/// games plug in by adding a `GameKind` case and a setup view below.
struct GamesSheet: View {
    @Environment(\.dismiss) private var dismiss
    let partnerName: String
    var onStart: (GameSession) -> Void

    @State private var path: [GameKind] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: Theme.Spacing.m) {
                    ForEach(GameKind.allCases) { kind in
                        NavigationLink(value: kind) {
                            HStack(spacing: Theme.Spacing.l) {
                                Image(systemName: kind.icon)
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 54, height: 54)
                                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.Gradients.seeded(kind.seed)))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(kind.title)
                                        .font(.ui(17, weight: .semibold))
                                        .foregroundStyle(Theme.Palette.textPrimary)
                                    Text(kind.subtitle)
                                        .font(.ui(13))
                                        .foregroundStyle(Theme.Palette.textSecondary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.Palette.textTertiary)
                            }
                            .cardStyle(padding: Theme.Spacing.m)
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(Theme.Spacing.xl)
            }
            .screenBackground()
            .navigationTitle("Play with \(partnerName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .navigationDestination(for: GameKind.self) { kind in
                setup(for: kind)
                    .screenBackground()
                    .navigationTitle(kind.title)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    @ViewBuilder
    private func setup(for kind: GameKind) -> some View {
        switch kind {
        case .questionCards: QuestionCardsSetup(onStart: onStart)
        case .wouldYouRather: WouldYouRatherSetup(onStart: onStart)
        case .twoTruths: TwoTruthsSetup(partnerName: partnerName, onStart: onStart)
        case .challenge: ChallengeSetup(onStart: onStart)
        }
    }
}

// MARK: - Question Cards

struct QuestionCardsSetup: View {
    var onStart: (GameSession) -> Void
    @State private var category: QuestionCategory?
    @State private var question = ""
    @State private var flip = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                LazyVGrid(columns: columns, spacing: Theme.Spacing.m) {
                    ForEach(QuestionCategory.allCases) { c in
                        Button {
                            category = c
                            draw()
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: c.icon).font(.system(size: 20))
                                Text(c.title)
                                    .font(.ui(12, weight: .semibold))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity, minHeight: 84)
                            .padding(6)
                            .foregroundStyle(category == c ? .white : Theme.Palette.textPrimary)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                                .fill(category == c ? AnyShapeStyle(Theme.Gradients.accent) : AnyShapeStyle(Theme.Palette.surface)))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                                .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
                        }
                        .buttonStyle(.pressable)
                    }
                }

                if let category {
                    VStack(spacing: Theme.Spacing.l) {
                        QuestionCardFace(category: category, question: question)
                            .rotation3DEffect(.degrees(flip ? 360 : 0), axis: (x: 0, y: 1, z: 0))
                        HStack {
                            Button { draw() } label: { Label("Another", systemImage: "shuffle") }
                                .buttonStyle(SecondaryButtonStyle())
                            Button {
                                onStart(GameSession(startedBy: .me, state: .question(
                                    QuestionRound(category: category, question: question, myAnswer: nil, theirAnswer: nil))))
                            } label: { Label("Send card", systemImage: "paperplane.fill") }
                                .buttonStyle(.primary)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Text("Choose a theme — we'll draw a question you both answer.")
                        .font(.ui(14))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .padding(Theme.Spacing.xl)
        }
        .animation(Theme.Motion.snappy, value: category)
    }

    private func draw() {
        guard let category else { return }
        var next = GameLibrary.randomQuestion(in: category)
        var attempts = 0
        while next == question && attempts < 5 {
            next = GameLibrary.randomQuestion(in: category)
            attempts += 1
        }
        withAnimation(.easeInOut(duration: 0.5)) {
            flip.toggle()
            question = next
        }
    }
}

struct QuestionCardFace: View {
    let category: QuestionCategory
    let question: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Label(category.title, systemImage: category.icon)
                .font(.ui(12, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .opacity(0.8)
            Text(question)
                .font(.display(24, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            HStack {
                Spacer()
                Image(systemName: "waterbottle").opacity(0.5)
            }
        }
        .foregroundStyle(.white)
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous).fill(Theme.Gradients.night))
        .shadow(color: Theme.Palette.deepOcean.opacity(0.25), radius: 20, x: 0, y: 12)
    }
}

// MARK: - Would You Rather

struct WouldYouRatherSetup: View {
    var onStart: (GameSession) -> Void
    @State private var pair = GameLibrary.randomWouldYouRather()

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Text("Would you rather…")
                .font(.display(26, weight: .bold))
            VStack(spacing: Theme.Spacing.m) {
                option(pair.0, seed: 3)
                Text("or").font(.display(18)).italic().foregroundStyle(Theme.Palette.textSecondary)
                option(pair.1, seed: 2)
            }
            .id(pair.0 + pair.1)
            .transition(.push(from: .trailing))
            Spacer()
            HStack {
                Button {
                    withAnimation(Theme.Motion.snappy) { pair = GameLibrary.randomWouldYouRather() }
                } label: { Label("Shuffle", systemImage: "shuffle") }
                    .buttonStyle(SecondaryButtonStyle())
                Button {
                    onStart(GameSession(startedBy: .me, state: .wouldYouRather(
                        WouldYouRatherRound(optionA: pair.0, optionB: pair.1, myChoice: nil, theirChoice: nil))))
                } label: { Label("Send", systemImage: "paperplane.fill") }
                    .buttonStyle(.primary)
            }
        }
        .padding(Theme.Spacing.xl)
    }

    private func option(_ text: String, seed: Int) -> some View {
        Text(text)
            .font(.ui(18, weight: .semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 90)
            .padding()
            .background(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous).fill(Theme.Gradients.seeded(seed)))
    }
}

// MARK: - Two Truths and a Lie

struct TwoTruthsSetup: View {
    let partnerName: String
    var onStart: (GameSession) -> Void
    @State private var statements = ["", "", ""]
    @State private var lieIndex: Int?

    private var isReady: Bool {
        lieIndex != nil && statements.allSatisfy { $0.trimmingCharacters(in: .whitespaces).count >= 3 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                Text("Write three statements about yourself. Mark the lie — \(partnerName) has to find it.")
                    .font(.ui(15))
                    .foregroundStyle(Theme.Palette.textSecondary)
                ForEach(0..<3, id: \.self) { i in
                    HStack(spacing: Theme.Spacing.m) {
                        TextField("Statement \(i + 1)", text: $statements[i], axis: .vertical)
                            .font(.ui(16))
                            .lineLimit(1...3)
                        Button {
                            withAnimation(Theme.Motion.snappy) { lieIndex = i }
                        } label: {
                            Text(lieIndex == i ? "Lie" : "Truth")
                                .font(.ui(12, weight: .bold))
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .foregroundStyle(lieIndex == i ? .white : Theme.Palette.textSecondary)
                                .background(Capsule().fill(lieIndex == i ? Theme.Palette.coral : Theme.Palette.surfaceMuted))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(lieIndex == i ? "Marked as the lie" : "Mark statement \(i + 1) as the lie")
                    }
                    .padding(Theme.Spacing.m)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.medium).fill(Theme.Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium)
                        .strokeBorder(lieIndex == i ? Theme.Palette.coral : Theme.Palette.hairline, lineWidth: lieIndex == i ? 1.5 : 0.5))
                }
                Text(lieIndex == nil ? "Tap “Truth” on one statement to mark it as the lie." : "The lie stays secret until \(partnerName) guesses.")
                    .font(.ui(12))
                    .foregroundStyle(Theme.Palette.textTertiary)
                Button {
                    guard let lieIndex else { return }
                    onStart(GameSession(startedBy: .me, state: .twoTruths(TwoTruthsRound(
                        author: .me,
                        statements: statements.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
                        lieIndex: lieIndex, guess: nil))))
                } label: { Label("Challenge \(partnerName)", systemImage: "paperplane.fill") }
                    .buttonStyle(.primary)
                    .disabled(!isReady)
                    .padding(.top, Theme.Spacing.m)
            }
            .padding(Theme.Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Random challenge

struct ChallengeSetup: View {
    var onStart: (GameSession) -> Void
    @State private var challenge = GameLibrary.randomChallenge()
    @State private var spins = 0

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            Image(systemName: "flag.checkered")
                .font(.system(size: 44))
                .foregroundStyle(Theme.Palette.coral)
                .symbolEffect(.bounce, value: spins)
            Text(challenge)
                .font(.display(24, weight: .semibold))
                .multilineTextAlignment(.center)
                .id(challenge)
                .transition(.scale.combined(with: .opacity))
            Text("Small, harmless and fun. Both of you can accept or pass.")
                .font(.ui(14))
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            HStack {
                Button {
                    spins += 1
                    withAnimation(Theme.Motion.bouncy) { challenge = GameLibrary.randomChallenge() }
                } label: { Label("Spin", systemImage: "dice") }
                    .buttonStyle(SecondaryButtonStyle())
                Button {
                    onStart(GameSession(startedBy: .me, state: .challenge(
                        ChallengeRound(text: challenge, myStatus: .accepted, theirStatus: .pending))))
                } label: { Label("Send", systemImage: "paperplane.fill") }
                    .buttonStyle(.primary)
            }
        }
        .padding(Theme.Spacing.xl)
    }
}
