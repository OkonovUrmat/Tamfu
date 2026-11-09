import SwiftUI

@main
struct TamfuApp: App {
    @State private var model = AppModel(services: .mock())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(model.settings.theme.colorScheme)
                .tint(Theme.Palette.accent)
        }
    }
}

extension AppTheme {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            switch model.session {
            case .launching:
                LaunchView()
                    .transition(.opacity)
            case .signedOut:
                WelcomeView()
                    .transition(.opacity)
            case .signedIn:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            if let toast = model.toast {
                ToastView(toast: toast)
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.top, Theme.Spacing.s)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { withAnimation { model.toast = nil } }
                    .zIndex(10)
            }
        }
        .task { await model.bootstrap() }
    }
}

struct LaunchView: View {
    var body: some View {
        ZStack {
            Theme.Gradients.ocean.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.l) {
                BottleIllustration(size: 120, glow: true)
                    .floating()
                Text("Message in a Bottle")
                    .font(.display(28))
                    .foregroundStyle(.white)
            }
        }
    }
}
