import SwiftUI

/// Only this tiny ring refreshes; the timer text updates itself through SwiftUI.
struct FocusTimerRing: View {
    var session: FocusSession

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let total = Double(session.durationMinutes * 60)
            let progress = 1 - session.remaining(at: context.date) / total
            ProgressRing(progress: progress, width: 5)
        }
    }
}
