import SwiftUI

struct RitualCheck: View {
    var completed: Bool
    var progress: Double = 0
    var label = "Complete ritual"
    var feedbackEnabled = true
    var action: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion
    @Environment(\.haloHapticsEnabled) private var haptics

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().stroke(palette.hairline, lineWidth: 1.5)
                Circle()
                    .trim(from: 0, to: completed ? 1 : progress)
                    .stroke(palette.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Circle()
                    .fill(palette.accent)
                    .scaleEffect(reduceMotion ? 1 : (completed ? 1 : 0))
                    .opacity(completed ? 1 : 0)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.accentOn)
                    .opacity(completed ? 1 : 0)
                    .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? false : completed)
            }
            .frame(width: 26, height: 26)
            .frame(width: 44, height: 44)
            .overlay { burst.allowsHitTesting(false) }
            .animation(reduceMotion ? nil : Motion.snappy, value: completed)
            .animation(reduceMotion ? nil : Motion.snappy, value: progress)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(Text(LocalizedStringKey(label)))
        .accessibilityValue(completed ? Text("Completed") : Text("Not completed"))
        .sensoryFeedback(.success, trigger: completed) { _, new in new && haptics && feedbackEnabled }
    }

    private var burst: some View {
        let enabled = completed && !reduceMotion
        let color = palette.accent
        return Color.clear
            .frame(width: 64, height: 64)
            .keyframeAnimator(initialValue: 0.0, trigger: completed) { _, phase in
                Canvas { context, size in
                    guard enabled && phase > 0 else { return }
                    for index in 0..<6 {
                        let angle = Double(index) * .pi / 3
                        let radius = 12 + phase * 18
                        let point = CGPoint(
                            x: size.width / 2 + CGFloat(cos(angle) * radius),
                            y: size.height / 2 + CGFloat(sin(angle) * radius)
                        )
                        let rect = CGRect(x: point.x - 1.5, y: point.y - 1.5, width: 3, height: 3)
                        context.fill(Path(ellipseIn: rect), with: .color(color.opacity(1 - phase)))
                    }
                }
            } keyframes: { _ in
                LinearKeyframe(0, duration: 0.01)
                CubicKeyframe(1, duration: 0.45)
                LinearKeyframe(0, duration: 0.01)
            }
    }
}

#Preview("Ritual · Light") {
    @Previewable @State var done = false
    DesignPreview { RitualCheck(completed: done) { done.toggle() } }
}

#Preview("Ritual · Ruby AX3 Reduced Motion") {
    DesignPreview(themeID: "rubyGlass", scheme: .dark, accessibility: true, reduceMotion: true) {
        RitualCheck(completed: true) { }
    }
}
