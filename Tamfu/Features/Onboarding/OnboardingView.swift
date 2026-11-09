import SwiftUI

@MainActor
@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable { case name, birthday, location, interests, guidelines }

    var step: Step = .name
    var name = ""
    var birthDate = Calendar.current.date(byAdding: .year, value: -24, to: .now) ?? .now
    var country: Country = Country.named("KG")
    var city = ""
    var interests: Set<String> = []
    var hobbies: Set<String> = []
    var acceptedGuidelines = false
    var isSubmitting = false
    var errorMessage: String?

    var age: Int { Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 0 }
    var isUnderage: Bool { age < BottleRules.minimumAge }

    var canContinue: Bool {
        switch step {
        case .name: return name.trimmingCharacters(in: .whitespaces).count >= 2
        case .birthday: return !isUnderage
        case .location: return true
        case .interests: return interests.count + hobbies.count >= 3
        case .guidelines: return acceptedGuidelines
        }
    }

    var progress: Double { Double(step.rawValue + 1) / Double(Step.allCases.count) }

    func next() {
        guard let nextStep = Step(rawValue: step.rawValue + 1) else { return }
        withAnimation(Theme.Motion.snappy) { step = nextStep }
    }

    func back() {
        guard let prev = Step(rawValue: step.rawValue - 1) else { return }
        withAnimation(Theme.Motion.snappy) { step = prev }
    }

    func makeProfile() -> UserProfile {
        UserProfile(
            name: name.trimmingCharacters(in: .whitespaces),
            birthDate: birthDate,
            country: country,
            city: city.trimmingCharacters(in: .whitespaces),
            bio: "",
            status: "New to the ocean 🌊",
            languages: ["English"],
            interests: Array(interests).sorted(),
            hobbies: Array(hobbies).sorted(),
            isOnline: true,
            avatarSeed: Int.random(in: 0...20)
        )
    }
}

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var vm = OnboardingViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    stepContent
                }
                .id(vm.step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
                .padding(Theme.Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)

            footer
        }
        .screenBackground()
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.l) {
            HStack {
                Button {
                    if vm.step == .name { dismiss() } else { vm.back() }
                } label: {
                    Image(systemName: vm.step == .name ? "xmark" : "chevron.left")
                }
                .buttonStyle(CircleIconButtonStyle(size: 40))
                Spacer()
                Text("Step \(vm.step.rawValue + 1) of \(OnboardingViewModel.Step.allCases.count)")
                    .font(.ui(13, weight: .medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            ProgressView(value: vm.progress)
                .tint(Theme.Palette.accent)
                .animation(Theme.Motion.snappy, value: vm.progress)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.l)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch vm.step {
        case .name:
            title("What should people call you?", "Only your first name is shown to strangers.")
            TextField("Your name", text: $vm.name)
                .font(.display(28))
                .textContentType(.givenName)
                .padding(.vertical, Theme.Spacing.m)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.Palette.hairline).frame(height: 1) }

        case .birthday:
            title("When's your birthday?", "Message in a Bottle is for adults only. Your exact date stays private.")
            DatePicker("Birthday", selection: $vm.birthDate, in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            if vm.isUnderage {
                Label("You must be 18 or older to join.", systemImage: "exclamationmark.triangle.fill")
                    .font(.ui(14, weight: .medium))
                    .foregroundStyle(Theme.Palette.danger)
            } else {
                Text("You're \(vm.age)")
                    .font(.ui(15))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }

        case .location:
            title("Where's your shore?", "Your country helps people discover cultures. You can hide your city later.")
            Picker("Country", selection: $vm.country) {
                ForEach(Country.all) { c in
                    Text("\(c.flag)  \(c.name)").tag(c)
                }
            }
            .pickerStyle(.wheel)
            TextField("City (optional)", text: $vm.city)
                .font(.ui(17))
                .padding()
                .background(RoundedRectangle(cornerRadius: Theme.Radius.medium).fill(Theme.Palette.surface))

        case .interests:
            title("What lights you up?", "Pick at least 3 — interests and hobbies together.")
            Text("Interests").font(.ui(15, weight: .semibold))
            ChipPicker(options: MockData.allInterests, selection: $vm.interests)
            Text("Hobbies").font(.ui(15, weight: .semibold)).padding(.top, Theme.Spacing.s)
            ChipPicker(options: MockData.allHobbies, selection: $vm.hobbies)

        case .guidelines:
            title("A kind ocean", "A few promises that keep conversations with strangers safe.")
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                guideline("hand.raised", "Be respectful", "No harassment, hate or explicit content.")
                guideline("lock.shield", "Protect your privacy", "Don't share addresses, phone numbers or financial info.")
                guideline("eye.slash", "You're in control", "You decide what to reveal, and when.")
                guideline("exclamationmark.bubble", "Report & block", "If something feels off, report it — we review every report.")
            }
            .cardStyle()
            Toggle(isOn: $vm.acceptedGuidelines) {
                Text("I'm 18+ and agree to the Community Guidelines")
                    .font(.ui(15, weight: .medium))
            }
            .tint(Theme.Palette.accent)
            if let error = vm.errorMessage {
                Text(error).font(.ui(14)).foregroundStyle(Theme.Palette.danger)
            }
        }
    }

    private var footer: some View {
        Button {
            if vm.step == .guidelines {
                submit()
            } else {
                hideKeyboard()
                vm.next()
            }
        } label: {
            HStack {
                if vm.isSubmitting { ProgressView().tint(.white) }
                Text(vm.step == .guidelines ? "Throw my first bottle" : "Continue")
            }
        }
        .buttonStyle(.primary)
        .disabled(!vm.canContinue || vm.isSubmitting)
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.l)
    }

    private func submit() {
        vm.isSubmitting = true
        vm.errorMessage = nil
        Task {
            do {
                try await model.completeOnboarding(with: vm.makeProfile())
                dismiss()
            } catch {
                vm.errorMessage = error.localizedDescription
            }
            vm.isSubmitting = false
        }
    }

    private func title(_ text: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(text)
                .font(.display(30, weight: .bold))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(subtitle)
                .font(.ui(16))
                .foregroundStyle(Theme.Palette.textSecondary)
        }
    }

    private func guideline(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Theme.Palette.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.ui(15, weight: .semibold))
                Text(text).font(.ui(14)).foregroundStyle(Theme.Palette.textSecondary)
            }
        }
    }
}
