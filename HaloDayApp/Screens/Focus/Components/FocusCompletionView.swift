import SwiftUI

struct FocusCompletionView: View {
    var session: FocusSession
    var onDone: () -> Void
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion
    @Environment(\.haloHapticsEnabled) private var haptics
    @State private var appeared = false

    var body: some View {
        ZStack {
            ThemeBackground()
            VStack(spacing: 32) {
                Spacer()
                ProgressRing(progress: 1, width: 4)
                    .frame(width: 160, height: 160)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(palette.accent)
                    }
                    .shadow(color: palette.accent.opacity(appeared ? 0.2 : 0), radius: 30)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.96)
                Text("\(session.durationMinutes) minutes of focus. Beautiful.")
                    .haloFont(.displayL)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                HaloButton(title: "Done", action: onDone)
            }
            .padding(28)
        }
        .onAppear { appeared = true }
        .animation(Motion.resolve(Motion.gentle, reduceMotion: reduceMotion), value: appeared)
        .sensoryFeedback(.success, trigger: appeared) { _, new in new && haptics }
    }
}

#Preview("Completion · Ruby") {
    let date = Date.now
    DesignPreview(themeID: "rubyGlass", scheme: .dark) {
        FocusCompletionView(session: FocusSession(title: "Deep work", startDate: date, endDate: date, durationMinutes: 50, accentColor: ThemeRegistry.theme("rubyGlass").dark.accent, isActive: false), onDone: {})
    }
}

#Preview("Completion · Gold AX3") {
    let date = Date.now
    DesignPreview(themeID: "midnightGold", scheme: .dark, accessibility: true, reduceMotion: true) {
        FocusCompletionView(session: FocusSession(title: "Deep work", startDate: date, endDate: date, durationMinutes: 25, accentColor: ThemeRegistry.theme("midnightGold").dark.accent, isActive: false), onDone: {})
    }
}
