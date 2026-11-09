import SwiftUI

/// Interactive in-chat card for any mini-game session.
struct GameCardView: View {
    @Environment(AppModel.self) private var model
    let message: ChatMessage
    let session: GameSession
    let partnerName: String
    let vm: ChatViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            header
            switch session.state {
            case .question(let round):
                QuestionGameBody(round: round, partnerName: partnerName) { answer in
                    var r = round
                    r.myAnswer = answer
                    vm.play(message, newState: .question(r), using: model)
                }
            case .wouldYouRather(let round):
                WouldYouRatherBody(round: round, partnerName: partnerName) { choice in
                    var r = round
                    r.myChoice = choice
                    vm.play(message, newState: .wouldYouRather(r), using: model)
                }
            case .twoTruths(let round):
                TwoTruthsBody(round: round, partnerName: partnerName) { guess in
                    var r = round
                    r.guess = guess
                    vm.play(message, newState: .twoTruths(r), using: model)
                }
            case .challenge(let round):
                ChallengeBody(round: round, partnerName: partnerName) { status in
                    var r = round
                    r.myStatus = status
                    vm.play(message, newState: .challenge(r), using: model)
                }
            }
        }
        .padding(Theme.Spacing.l)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .fill(Theme.Palette.surface)
                .shadow(color: Theme.Palette.deepOcean.opacity(0.08), radius: 14, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
        )
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, Theme.Spacing.s)
        .animation(Theme.Motion.snappy, value: session)
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: session.kind.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.Gradients.seeded(session.kind.seed)))
            Text(session.kind.title)
                .font(.ui(13, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("· \(session.startedBy == .me ? "you started" : "\(partnerName) started")")
                .font(.ui(12))
                .foregroundStyle(Theme.Palette.textTertiary)
            Spacer()
            if session.isComplete {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.Palette.success)
                    .transition(.scale)
            }
        }
    }
}

// MARK: - Question

struct QuestionGameBody: View {
    let round: QuestionRound
    let partnerName: String
    var onAnswer: (String) -> Void
    @State private var answer = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            QuestionCardFace(category: round.category, question: round.question)
                .frame(minHeight: 160)
                .scaleEffect(0.98)

            answerRow(title: "You", text: round.myAnswer, isMine: true)
            if round.myAnswer == nil {
                HStack {
                    TextField("Your answer…", text: $answer, axis: .vertical)
                        .lineLimit(1...4)
                        .font(.ui(15))
                    Button {
                        let value = answer.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !value.isEmpty else { return }
                        onAnswer(value)
                        answer = ""
                    } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 26))
                    }
                    .disabled(answer.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.Palette.surfaceMuted))
            }
            answerRow(title: partnerName, text: round.theirAnswer, isMine: false)
        }
    }

    @ViewBuilder
    private func answerRow(title: String, text: String?, isMine: Bool) -> some View {
        if let text {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.ui(12, weight: .semibold)).foregroundStyle(Theme.Palette.accent)
                // Hide the partner's answer until you've answered, so neither influences the other.
                if !isMine && round.myAnswer == nil {
                    Text("Answered — reply to reveal 🔒")
                        .font(.ui(14)).italic()
                        .foregroundStyle(Theme.Palette.textSecondary)
                } else {
                    Text(text).font(.ui(15)).foregroundStyle(Theme.Palette.textPrimary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.m)
            .background(RoundedRectangle(cornerRadius: 14).fill(isMine ? Theme.Palette.accentSoft : Theme.Palette.surfaceMuted))
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        } else if !isMine {
            Text("Waiting for \(title)…")
                .font(.ui(13)).italic()
                .foregroundStyle(Theme.Palette.textTertiary)
        }
    }
}

// MARK: - Would you rather

struct WouldYouRatherBody: View {
    let round: WouldYouRatherRound
    let partnerName: String
    var onChoose: (Int) -> Void

    private var revealed: Bool { round.myChoice != nil }

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            option(round.optionA, index: 0)
            Text("or").font(.display(14)).italic().foregroundStyle(Theme.Palette.textSecondary)
            option(round.optionB, index: 1)
            if revealed {
                Group {
                    if let theirs = round.theirChoice {
                        Text(theirs == round.myChoice ? "Same choice! 🌊 Great minds." : "Opposite sides — explain yourselves 😄")
                    } else {
                        Text("Waiting for \(partnerName)…")
                    }
                }
                .font(.ui(13, weight: .medium))
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.top, 4)
            } else {
                Text("Tap your choice. \(partnerName)'s pick stays hidden until you answer.")
                    .font(.ui(12))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
    }

    private func option(_ text: String, index: Int) -> some View {
        let mine = round.myChoice == index
        let theirs = revealed && round.theirChoice == index
        return Button { onChoose(index) } label: {
            HStack {
                Text(text)
                    .font(.ui(15, weight: .semibold))
                    .multilineTextAlignment(.leading)
                Spacer()
                HStack(spacing: -6) {
                    if mine { badge("You", color: Theme.Palette.accent) }
                    if theirs { badge(String(partnerName.prefix(1)), color: Theme.Palette.coral) }
                }
            }
            .foregroundStyle(mine ? .white : Theme.Palette.textPrimary)
            .padding(Theme.Spacing.m)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(mine ? AnyShapeStyle(Theme.Gradients.night) : AnyShapeStyle(Theme.Palette.surfaceMuted)))
        }
        .buttonStyle(.pressable)
        .disabled(revealed)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.ui(10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7).padding(.vertical, 4)
            .background(Capsule().fill(color))
            .overlay(Capsule().strokeBorder(.white, lineWidth: 1.5))
    }
}

// MARK: - Two truths and a lie

struct TwoTruthsBody: View {
    let round: TwoTruthsRound
    let partnerName: String
    var onGuess: (Int) -> Void

    private var iAmGuessing: Bool { round.author == .them }
    private var finished: Bool { round.guess != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(iAmGuessing ? "Which one is \(partnerName)'s lie?" : "Your statements — can \(partnerName) spot the lie?")
                .font(.ui(14, weight: .medium))
                .foregroundStyle(Theme.Palette.textSecondary)
            ForEach(round.statements.indices, id: \.self) { i in
                Button { onGuess(i) } label: {
                    HStack(alignment: .top, spacing: Theme.Spacing.s) {
                        Text("\(i + 1)")
                            .font(.roundedUI(13, weight: .bold))
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Theme.Palette.accentSoft))
                            .foregroundStyle(Theme.Palette.accent)
                        Text(round.statements[i])
                            .font(.ui(15))
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Spacer()
                        trailing(i)
                    }
                    .padding(Theme.Spacing.m)
                    .background(RoundedRectangle(cornerRadius: 14).fill(fill(i)))
                }
                .buttonStyle(.pressable)
                .disabled(!iAmGuessing || finished)
            }
            if finished, let guess = round.guess {
                Text(resultText(guess))
                    .font(.ui(14, weight: .semibold))
                    .foregroundStyle(guess == round.lieIndex ? Theme.Palette.success : Theme.Palette.coral)
                    .transition(.scale.combined(with: .opacity))
            } else if !iAmGuessing {
                Text("Waiting for \(partnerName)'s guess…").font(.ui(13)).italic().foregroundStyle(Theme.Palette.textTertiary)
            }
        }
    }

    private func resultText(_ guess: Int) -> String {
        let correct = guess == round.lieIndex
        if iAmGuessing { return correct ? "You caught the lie! 🎯" : "Nope — the lie was #\(round.lieIndex + 1) 😄" }
        return correct ? "\(partnerName) caught your lie 🎯" : "\(partnerName) guessed #\(guess + 1) — you fooled them 😎"
    }

    private func fill(_ i: Int) -> Color {
        guard finished else { return Theme.Palette.surfaceMuted }
        if i == round.lieIndex { return Theme.Palette.coral.opacity(0.18) }
        return Theme.Palette.success.opacity(0.12)
    }

    @ViewBuilder
    private func trailing(_ i: Int) -> some View {
        if finished {
            Text(i == round.lieIndex ? "Lie" : "Truth")
                .font(.ui(11, weight: .bold))
                .foregroundStyle(i == round.lieIndex ? Theme.Palette.coral : Theme.Palette.success)
        } else if !iAmGuessing && i == round.lieIndex {
            Image(systemName: "eye.slash").font(.system(size: 12)).foregroundStyle(Theme.Palette.textTertiary)
        }
    }
}

// MARK: - Challenge

struct ChallengeBody: View {
    let round: ChallengeRound
    let partnerName: String
    var onUpdate: (ChallengeStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text(round.text)
                .font(.display(19, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Theme.Spacing.m) {
                status("You", round.myStatus)
                status(partnerName, round.theirStatus)
            }
            switch round.myStatus {
            case .pending:
                HStack {
                    promptButton("Accept", filled: true) { onUpdate(.accepted) }
                    promptButton("Pass", filled: false) { onUpdate(.passed) }
                }
            case .accepted:
                promptButton("Mark as done ✓", filled: true) { onUpdate(.done) }
            case .done, .passed:
                EmptyView()
            }
        }
    }

    private func status(_ name: String, _ status: ChallengeStatus) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.ui(11, weight: .semibold)).foregroundStyle(Theme.Palette.textTertiary)
            Text(status.label).font(.ui(13, weight: .semibold))
                .foregroundStyle(status == .done ? Theme.Palette.success : status == .passed ? Theme.Palette.textTertiary : Theme.Palette.accent)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Palette.surfaceMuted))
    }
}
