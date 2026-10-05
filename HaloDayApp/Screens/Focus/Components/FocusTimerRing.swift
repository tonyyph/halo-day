import SwiftUI

/// A single interpolation runs to the end date. No timer invalidates the view.
struct FocusTimerRing: View {
    var session: FocusSession
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion
    @State private var progress = 0.0

    var body: some View {
        ZStack {
            Circle().stroke(palette.hairline, lineWidth: 5)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(
                    AngularGradient(colors: [palette.accent, palette.accent.opacity(0.7)], center: .center),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .padding(2.5)
        .task(id: session) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                progress = 1 - session.remaining() / Double(session.durationMinutes * 60)
            }
            guard !session.isPaused && !reduceMotion else { return }
            // Commit the initial arc before beginning the long interpolation.
            try? await Task.sleep(for: .milliseconds(30))
            guard !Task.isCancelled else { return }
            withAnimation(Motion.timer(session.remaining())) { progress = 1 }
        }
    }
}
