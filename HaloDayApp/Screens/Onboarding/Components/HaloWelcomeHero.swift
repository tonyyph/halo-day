import SwiftUI

struct HaloWelcomeHero: View {
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion
    @State private var ringProgress = 0.0
    @State private var wordProgress = 0.0

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle().fill(palette.accentSoft.opacity(0.6))
                    .frame(width: 140, height: 140)
                    .shadow(color: palette.accentSoft, radius: 24)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(palette.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Circle().fill(palette.accent)
                    .frame(width: 8, height: 8)
                    .offset(x: 67, y: -44)
                    .opacity(ringProgress > 0.75 ? 1 : 0)
            }
            .frame(width: 160, height: 160)
            .accessibilityHidden(true)

            if reduceMotion {
                Text("Halo Day").haloFont(.displayXL).opacity(wordProgress)
            } else {
                Text("Halo Day")
                    .haloFont(.displayXL)
                    .multilineTextAlignment(.center)
                    .textRenderer(HaloWordmarkRenderer(progress: wordProgress))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .task {
            if reduceMotion {
                ringProgress = 1
                withAnimation(Motion.resolve(Motion.gentle, reduceMotion: true)) { wordProgress = 1 }
            } else {
                withAnimation(Motion.draw) { ringProgress = 1 }
                try? await Task.sleep(for: .seconds(1.2))
                guard !Task.isCancelled else { return }
                withAnimation(Motion.gentle) { wordProgress = 1 }
            }
        }
    }
}

private struct HaloWordmarkRenderer: TextRenderer {
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var displayPadding: EdgeInsets { EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0) }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let glyphs = layout.flatMap { line in line.flatMap { run in Array(run) } }
        let count = Double(max(1, glyphs.count))
        for (index, glyph) in glyphs.enumerated() {
            let value = min(1, max(0, progress * 1.4 - Double(index) / count * 0.4))
            var copy = context
            copy.opacity = value
            copy.translateBy(x: 0, y: (1 - value) * 10)
            copy.draw(glyph)
        }
    }
}

#Preview("Welcome · Light") {
    DesignPreview { HaloWelcomeHero() }
}

#Preview("Welcome · Ruby AX3 Reduced Motion") {
    DesignPreview(themeID: "rubyGlass", scheme: .dark, accessibility: true, reduceMotion: true) {
        HaloWelcomeHero()
    }
}
