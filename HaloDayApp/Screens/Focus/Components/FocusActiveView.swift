import SwiftUI

struct FocusActiveView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var confirmEnd = false

    var session: FocusSession

    var body: some View {
        ZStack {
            ThemeBackground()
            palette.bg.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()
                ZStack {
                    FocusTimerRing(session: session)
                    VStack(spacing: 16) {
                        Text(session.title)
                            .font(HaloFont.displayS)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        timerText
                        Text(session.isPaused ? "Paused" : "A little space, just for you.")
                            .font(HaloFont.caption)
                            .foregroundStyle(palette.ink2)
                    }
                    .padding(24)
                }
                .frame(width: 300, height: 300)

                HStack(spacing: 28) {
                    Button {
                        Task { await model.pauseFocus() }
                    } label: {
                        Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                            .font(.title2)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 64, height: 64)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel(session.isPaused ? "Resume" : "Pause")
                    .buttonStyle(PressableStyle())

                    Button("End", role: .destructive) { confirmEnd = true }
                        .font(HaloFont.subhead)
                        .frame(minWidth: 64, minHeight: 64)
                }
                Spacer()
            }
            .padding(24)
        }
        .task(id: session) {
            guard !session.isPaused else { return }
            do {
                try await Task.sleep(for: .seconds(session.remaining()))
                guard !Task.isCancelled else { return }
                await model.stopFocus(completed: true)
            } catch { }
        }
        .confirmationDialog("End this focus session?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End session", role: .destructive) {
                Task { await model.stopFocus() }
            }
        }
    }

    @ViewBuilder private var timerText: some View {
        if let remaining = session.pausedRemaining {
            Text(Duration.seconds(remaining), format: .time(pattern: .minuteSecond))
                .font(HaloFont.numericHero)
                .monospacedDigit()
        } else {
            Text(timerInterval: session.startDate...session.endDate, countsDown: true)
                .font(HaloFont.numericHero)
                .monospacedDigit()
        }
    }

}
