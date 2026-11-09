import SwiftUI

struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showOnboarding = false
    @State private var isSigningIn = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            Theme.Gradients.ocean.ignoresSafeArea()

            VStack {
                Spacer()
                OceanWaves(height: 220, tint: Theme.Palette.seafoam)
                    .opacity(0.9)
            }
            .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.xl) {
                Spacer()
                BottleIllustration(size: 190, glow: true)
                    .floating(amplitude: 12, rotation: 6)
                    .scaleEffect(appeared ? 1 : 0.7)
                    .opacity(appeared ? 1 : 0)

                VStack(spacing: Theme.Spacing.m) {
                    Text("Message in a Bottle")
                        .font(.display(36, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("Throw a message into the world.\nSomeone, somewhere, will find it.")
                        .font(.ui(17))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)

                Spacer()

                VStack(spacing: Theme.Spacing.m) {
                    Button("Get started") { showOnboarding = true }
                        .buttonStyle(.primary)

                    Button {
                        isSigningIn = true
                        Task {
                            await model.signInDemo()
                            isSigningIn = false
                        }
                    } label: {
                        HStack {
                            if isSigningIn { ProgressView().tint(.white) }
                            Text("Explore with a demo profile")
                        }
                        .font(.ui(16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(.white.opacity(0.14)))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                    }
                    .disabled(isSigningIn)

                    Text("18+ only. By continuing you agree to our Community Guidelines and Privacy Policy.")
                        .font(.ui(12))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.top, Theme.Spacing.xs)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.l)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { appeared = true }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
    }
}
