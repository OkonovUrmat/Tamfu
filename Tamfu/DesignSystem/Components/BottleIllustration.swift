import SwiftUI

/// Glass bottle silhouette: cork, neck, shoulders, body.
struct BottleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let neckW = w * 0.30
        let neckTop = h * 0.10
        let shoulder = h * 0.36
        let bodyRadius = w * 0.22
        var p = Path()
        let cx = rect.midX

        p.move(to: CGPoint(x: cx - neckW / 2, y: rect.minY + neckTop))
        p.addLine(to: CGPoint(x: cx - neckW / 2, y: rect.minY + h * 0.22))
        p.addCurve(to: CGPoint(x: rect.minX, y: rect.minY + shoulder + h * 0.08),
                   control1: CGPoint(x: cx - neckW / 2, y: rect.minY + h * 0.30),
                   control2: CGPoint(x: rect.minX, y: rect.minY + shoulder - h * 0.02))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - bodyRadius))
        p.addQuadCurve(to: CGPoint(x: rect.minX + bodyRadius, y: rect.maxY),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - bodyRadius, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - bodyRadius),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + shoulder + h * 0.08))
        p.addCurve(to: CGPoint(x: cx + neckW / 2, y: rect.minY + h * 0.22),
                   control1: CGPoint(x: rect.maxX, y: rect.minY + shoulder - h * 0.02),
                   control2: CGPoint(x: cx + neckW / 2, y: rect.minY + h * 0.30))
        p.addLine(to: CGPoint(x: cx + neckW / 2, y: rect.minY + neckTop))
        p.closeSubpath()
        return p
    }
}

struct BottleIllustration: View {
    var size: CGFloat = 160
    var glow = false
    var showsScroll = true

    var body: some View {
        let w = size * 0.52
        let h = size
        ZStack {
            if glow {
                Ellipse()
                    .fill(Theme.Palette.turquoise.opacity(0.35))
                    .frame(width: w * 1.8, height: h * 0.9)
                    .blur(radius: size * 0.22)
            }

            // Glass body
            BottleShape()
                .fill(
                    LinearGradient(colors: [
                        Theme.Palette.seafoam.opacity(0.55),
                        Theme.Palette.turquoise.opacity(0.35),
                        Theme.Palette.tide.opacity(0.55)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: w, height: h)

            // Rolled message inside
            if showsScroll {
                ScrollPaper()
                    .frame(width: w * 0.42, height: h * 0.42)
                    .rotationEffect(.degrees(-12))
                    .offset(y: h * 0.16)
            }

            // Highlights
            BottleShape()
                .stroke(
                    LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.15), .white.opacity(0.5)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: max(1.5, size * 0.012)
                )
                .frame(width: w, height: h)

            Capsule()
                .fill(.white.opacity(0.55))
                .frame(width: w * 0.08, height: h * 0.38)
                .offset(x: -w * 0.30, y: h * 0.14)
                .blur(radius: 0.6)

            // Cork
            RoundedRectangle(cornerRadius: size * 0.025, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xC8A27A), Color(hex: 0x9C7650)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: w * 0.34, height: h * 0.12)
                .offset(y: -h * 0.44)
        }
        .frame(width: w * 1.2, height: h)
        .accessibilityHidden(true)
    }
}

/// Rolled parchment with a ribbon.
struct ScrollPaper: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: w * 0.3, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0xFBF3DF), Color(hex: 0xE9D9B5)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: w * 0.62, height: h)
                VStack(spacing: h * 0.06) {
                    ForEach(0..<4, id: \.self) { _ in
                        Capsule().fill(Color(hex: 0xC9B48C).opacity(0.6))
                            .frame(width: w * 0.32, height: max(1, h * 0.02))
                    }
                }
                Capsule()
                    .fill(Theme.Palette.coral)
                    .frame(width: w * 0.66, height: h * 0.07)
            }
            .frame(width: w, height: h)
        }
    }
}

// MARK: - Ocean

struct WaveShape: Shape {
    var phase: Double
    var amplitude: CGFloat = 10
    var frequency: Double = 1.4

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let midY = rect.minY + amplitude
        p.move(to: CGPoint(x: rect.minX, y: midY))
        let step: CGFloat = 4
        var x: CGFloat = 0
        while x <= rect.width {
            let rel = Double(x / rect.width)
            let y = midY + amplitude * CGFloat(sin((rel * frequency * 2 * .pi) + phase))
            p.addLine(to: CGPoint(x: rect.minX + x, y: y))
            x += step
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Layered, slowly moving waves.
struct OceanWaves: View {
    var height: CGFloat = 160
    var tint: Color = Theme.Palette.turquoise

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                WaveShape(phase: t * 0.9, amplitude: 9, frequency: 1.2)
                    .fill(tint.opacity(0.18))
                    .offset(y: 0)
                WaveShape(phase: t * 1.3 + 1.5, amplitude: 11, frequency: 1.6)
                    .fill(tint.opacity(0.22))
                    .offset(y: 22)
                WaveShape(phase: t * 0.7 + 3, amplitude: 8, frequency: 1.0)
                    .fill(Theme.Palette.tide.opacity(0.28))
                    .offset(y: 46)
            }
        }
        .frame(height: height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Floating motion

struct FloatingModifier: ViewModifier {
    var amplitude: CGFloat = 10
    var rotation: Double = 4
    var speed: Double = 1

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1 / 60)) { context in
            let t = context.date.timeIntervalSinceReferenceDate * speed
            content
                .offset(y: CGFloat(sin(t * 1.3)) * amplitude)
                .rotationEffect(.degrees(sin(t * 0.9) * rotation))
        }
    }
}

extension View {
    func floating(amplitude: CGFloat = 10, rotation: Double = 4, speed: Double = 1) -> some View {
        modifier(FloatingModifier(amplitude: amplitude, rotation: rotation, speed: speed))
    }
}
