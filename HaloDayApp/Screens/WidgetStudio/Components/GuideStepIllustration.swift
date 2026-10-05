import SwiftUI

struct GuideStepIllustration: View {
    var step: Int
    var home: Bool
    var active: Bool
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion

    var body: some View {
        let background = palette.bg
        let surface = palette.surfaceSunken
        let accent = palette.accent
        let ink = palette.ink
        let index = step
        let onHome = home
        Group {
            if active && !reduceMotion {
                Color.clear.phaseAnimator([0.0, 1.0]) { _, phase in
                    GuideIllustrationDrawing(step: index, home: onHome, phase: phase,
                                             background: background, surface: surface, accent: accent, ink: ink)
                } animation: { _ in Motion.phase }
            } else {
                GuideIllustrationDrawing(step: step, home: home, phase: 1,
                                         background: background, surface: surface, accent: accent, ink: ink)
            }
        }
        .frame(height: 190)
        .accessibilityHidden(true)
    }
}

private struct GuideIllustrationDrawing: View {
    let step: Int
    let home: Bool
    let phase: Double
    let background, surface, accent, ink: Color

    nonisolated init(step: Int, home: Bool, phase: Double, background: Color, surface: Color, accent: Color, ink: Color) {
        self.step = step; self.home = home; self.phase = phase
        self.background = background; self.surface = surface; self.accent = accent; self.ink = ink
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(background)
            VStack(spacing: 12) {
                Capsule().fill(ink).frame(width: 38, height: 10)
                Text("10:05").font(.system(size: 26, weight: .light, design: .rounded)).foregroundStyle(ink)
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(accent.opacity(0.3)).frame(width: 54, height: 24)
                    Circle().fill(accent.opacity(0.3)).frame(width: 24, height: 24)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
            if step == 0 {
                Circle().stroke(accent.opacity(1 - phase), lineWidth: 2)
                    .frame(width: 44, height: 44).scaleEffect(0.7 + phase * 0.8).offset(y: 16)
                Image(systemName: "hand.tap.fill").foregroundStyle(accent).offset(x: 18, y: 34)
            } else if step == 1 {
                VStack(spacing: 8) {
                    Capsule().fill(ink.opacity(0.2)).frame(width: 26, height: 3)
                    Image(systemName: home ? "plus" : "slider.horizontal.3").foregroundStyle(accent)
                }
                .frame(maxWidth: .infinity).frame(height: 60)
                .background(surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .offset(y: 60 - phase * 30)
            } else if step == 2 {
                Image(systemName: "square.grid.2x2.fill").foregroundStyle(accent)
                    .font(.system(size: 32)).scaleEffect(0.9 + phase * 0.1).offset(y: 25)
            } else {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(accent)
                    .font(.system(size: 40)).opacity(0.5 + phase * 0.5).offset(y: 22)
            }
        }
        .frame(width: 112, height: 185)
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(ink.opacity(0.2), lineWidth: 3))
    }
}

#Preview("Guide · Light") {
    DesignPreview { GuideStepIllustration(step: 0, home: false, active: true) }
}

#Preview("Guide · Ruby AX3 Reduced Motion") {
    DesignPreview(themeID: "rubyGlass", scheme: .dark, accessibility: true, reduceMotion: true) {
        GuideStepIllustration(step: 1, home: true, active: true)
    }
}
