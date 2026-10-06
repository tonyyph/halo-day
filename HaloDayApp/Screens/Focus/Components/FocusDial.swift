import SwiftUI

struct FocusDial: View {
    @Binding var minutes: Int

    @Environment(\.palette) private var palette
    @Environment(\.haloHapticsEnabled) private var haptics
    @Environment(\.haloReduceMotion) private var reduceMotion

    private var progress: Double { Double(minutes - 5) / 235 }

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                ProgressRing(progress: progress, width: 8)

                Circle()
                    .fill(palette.accent)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(palette.accentOn.opacity(0.5), lineWidth: 1))
                    .shadow(color: palette.accent.opacity(0.25), radius: 10)
                    .offset(y: -(side - 8) / 2)
                    .rotationEffect(.degrees(progress * 360))

                VStack(spacing: 5) {
                    RollingNumber(value: minutes)
                        .haloFont(.numericHero)
                        .foregroundStyle(palette.ink)
                    Text("minutes, beautifully spent")
                        .haloFont(.subhead)
                        .foregroundStyle(palette.ink2)
                }
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        let dx = gesture.location.x - center.x
                        let dy = gesture.location.y - center.y
                        guard hypot(dx, dy) >= side * 0.32 else { return }
                        let radians = atan2(dx, -dy)
                        let normalized = radians < 0 ? radians + 2 * .pi : radians
                        var value = 5 + Int((normalized / (2 * .pi) * 235 / 5).rounded()) * 5
                        if minutes > 180 && value < 60 { value = 240 }
                        else if minutes < 60 && value > 180 { value = 5 }
                        if value != minutes {
                            withAnimation(Motion.resolve(Motion.snappy, reduceMotion: reduceMotion)) {
                                minutes = min(240, max(5, value))
                            }
                        }
                    }
            )
        }
        .frame(width: 260, height: 260)
        .sensoryFeedback(.selection, trigger: minutes) { _, _ in haptics }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Duration")
        .accessibilityValue("\(minutes) minutes")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: minutes = min(240, minutes + 5)
            case .decrement: minutes = max(5, minutes - 5)
            @unknown default: break
            }
        }
    }
}

#Preview {
    @Previewable @State var minutes = 50
    FocusDial(minutes: $minutes)
        .padding()
}

#Preview("Dial · Midnight Gold AX3 Reduced Motion") {
    @Previewable @State var minutes = 90
    DesignPreview(themeID: "midnightGold", scheme: .dark, accessibility: true, reduceMotion: true) {
        FocusDial(minutes: $minutes)
    }
}
