import SwiftUI

struct FocusActiveView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion
    @Environment(\.haloReduceTransparency) private var reduceTransparency
    @Environment(\.haloHapticsEnabled) private var haptics
    @Environment(\.dynamicTypeSize) private var dynamicType
    @State private var confirmEnd = false
    @State private var visible = false

    var session: FocusSession

    var body: some View {
        ZStack {
            ThemeBackground()
            palette.bg.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()
                ZStack {
                    if visible && !reduceMotion && !session.isPaused {
                        Circle().fill(palette.accentSoft)
                            .frame(width: 220, height: 220)
                            .shadow(color: palette.accentSoft.opacity(0.4), radius: 30)
                            .phaseAnimator([0.6, 0.9]) { view, phase in view.opacity(phase) } animation: { _ in Motion.breathe }
                    }
                    FocusTimerRing(session: session)
                    VStack(spacing: 16) {
                        timerText
                        Text(session.title)
                            .haloFont(.displayS)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        if !dynamicType.isAccessibilitySize {
                            Text(LocalizedStringKey(session.isPaused ? "Paused" : "A little space, just for you."))
                                .haloFont(.caption)
                                .foregroundStyle(palette.ink2)
                        }
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
                            .background {
                                if reduceTransparency { Circle().fill(palette.surface) }
                                else if #available(iOS 26.0, *) { Circle().fill(.clear).glassEffect(.regular, in: Circle()) }
                                else { Circle().fill(.ultraThinMaterial) }
                            }
                    }
                    .accessibilityLabel(session.isPaused ? "Resume" : "Pause")
                    .buttonStyle(PressableStyle())

                    Button("End", role: .destructive) { confirmEnd = true }
                        .haloFont(.subhead)
                        .frame(minWidth: 64, minHeight: 64)
                }
                Spacer()
            }
            .padding(24)
        }
        .onAppear { visible = true; UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { visible = false; UIApplication.shared.isIdleTimerDisabled = false }
        .sensoryFeedback(.selection, trigger: session.isPaused) { _, _ in haptics }
        .sensoryFeedback(.warning, trigger: confirmEnd) { _, new in new && haptics }
        .task(id: session) {
            guard !session.isPaused else { return }
            do {
                let clock = ContinuousClock()
                try await Task.sleep(until: clock.now.advanced(by: .seconds(session.remaining())), clock: clock)
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
                .haloFont(.numericHero)
                .monospacedDigit()
        } else {
            Text(timerInterval: session.startDate...session.endDate, countsDown: true)
                .haloFont(.numericHero)
                .monospacedDigit()
        }
    }

}
