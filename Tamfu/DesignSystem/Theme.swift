import SwiftUI
import UIKit

// MARK: - Color helpers

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(uiColor: UIColor(hex: hex, alpha: CGFloat(opacity)))
    }

    /// A color that adapts to light / dark mode.
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

// MARK: - Theme

enum Theme {
    enum Palette {
        // Brand
        static let deepOcean = Color(hex: 0x0B2545)
        static let midnight = Color(hex: 0x061528)
        static let tide = Color(hex: 0x13456B)
        static let turquoise = Color(hex: 0x3CC4C0)
        static let seafoam = Color(hex: 0x9DE3DB)
        static let coral = Color(hex: 0xF08A6C)
        static let sand = Color(hex: 0xE8DFCC)
        static let parchment = Color.adaptive(light: 0xFBF6EA, dark: 0x1A2B3D)

        // Semantic
        static let background = Color.adaptive(light: 0xF6F4EF, dark: 0x06121F)
        static let surface = Color.adaptive(light: 0xFFFFFF, dark: 0x0D1F33)
        static let surfaceMuted = Color.adaptive(light: 0xEEEBE3, dark: 0x132A42)
        static let textPrimary = Color.adaptive(light: 0x0B2545, dark: 0xF2F0EA)
        static let textSecondary = Color.adaptive(light: 0x5D6C80, dark: 0x93A5B8)
        static let textTertiary = Color.adaptive(light: 0x95A1B0, dark: 0x5F7389)
        static let hairline = Color.adaptive(light: 0xE3DFD5, dark: 0x1C3550)
        static let accent = Color.adaptive(light: 0x168F92, dark: 0x4FD1CB)
        static let accentSoft = Color.adaptive(light: 0xDDF3F1, dark: 0x103A42)
        static let bubbleMine = Color.adaptive(light: 0x0B2545, dark: 0x1D6F78)
        static let bubbleTheirs = Color.adaptive(light: 0xFFFFFF, dark: 0x132A42)
        static let danger = Color(hex: 0xE5484D)
        static let success = Color(hex: 0x30A46C)
        static let warning = Color(hex: 0xF5A524)
        static let online = Color(hex: 0x34C77B)
    }

    enum Gradients {
        static let ocean = LinearGradient(
            colors: [Palette.midnight, Palette.deepOcean, Palette.tide, Palette.turquoise.opacity(0.85)],
            startPoint: .top, endPoint: .bottom
        )
        static let accent = LinearGradient(
            colors: [Color(hex: 0x15898C), Color(hex: 0x3CC4C0)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        static let night = LinearGradient(
            colors: [Palette.deepOcean, Palette.tide],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        static let sunset = LinearGradient(
            colors: [Color(hex: 0xF08A6C), Color(hex: 0xF5C27A)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        static let cardScrim = LinearGradient(
            colors: [.clear, .black.opacity(0.15), .black.opacity(0.75)],
            startPoint: .center, endPoint: .bottom
        )

        /// Deterministic soft gradients used for avatars and placeholders.
        static func seeded(_ seed: Int) -> LinearGradient {
            let pairs: [(UInt32, UInt32)] = [
                (0x0B2545, 0x3CC4C0), (0x13456B, 0x9DE3DB), (0xF08A6C, 0xF5C27A),
                (0x5B5FC7, 0x9DE3DB), (0x1F7A8C, 0xBFDBF7), (0x8E6C8A, 0xF2C6B4),
                (0x2D6A4F, 0xB7E4C7), (0x3A506B, 0x5BC0BE), (0xC06C84, 0xF8B195)
            ]
            let pair = pairs[abs(seed) % pairs.count]
            return LinearGradient(colors: [Color(hex: pair.0), Color(hex: pair.1)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    enum Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 18
        static let large: CGFloat = 26
        static let xl: CGFloat = 34
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Motion {
        static let snappy = Animation.spring(response: 0.35, dampingFraction: 0.82)
        static let gentle = Animation.spring(response: 0.6, dampingFraction: 0.85)
        static let bouncy = Animation.spring(response: 0.45, dampingFraction: 0.62)
    }
}

// MARK: - Typography

extension Font {
    /// Editorial serif display type (New York).
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func roundedUI(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - View modifiers

struct CardStyle: ViewModifier {
    var padding: CGFloat = Theme.Spacing.l
    var radius: CGFloat = Theme.Radius.large

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
            )
            .shadow(color: Theme.Palette.deepOcean.opacity(0.06), radius: 18, x: 0, y: 8)
    }
}

extension View {
    func cardStyle(padding: CGFloat = Theme.Spacing.l, radius: CGFloat = Theme.Radius.large) -> some View {
        modifier(CardStyle(padding: padding, radius: radius))
    }

    func screenBackground() -> some View {
        background(Theme.Palette.background.ignoresSafeArea())
    }
}

/// Dismisses the software keyboard.
@MainActor
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
