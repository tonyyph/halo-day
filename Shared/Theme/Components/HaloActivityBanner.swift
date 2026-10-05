import SwiftUI
import ActivityKit
import WidgetKit

struct HaloActivityBanner: View {
    let attributes: HaloActivityAttributes
    let state: HaloActivityAttributes.ContentState
    var interactive = true

    private var colors: ResolvedPalette {
        PaletteResolver.resolve(ThemeRegistry.theme(attributes.themeId), scheme: .dark)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(attributes.isEvent ? "HALO DAY · COUNTDOWN" : "HALO DAY · FOCUS",
                      systemImage: attributes.isEvent ? "calendar" : "circle.dotted")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.8)
                Spacer(minLength: 0)
                if state.pausedRemaining != nil { Text("Paused").font(.caption) }
                else {
                    Text(state.endDate, style: .time).font(.caption.monospacedDigit())
                }
            }
            .foregroundStyle(colors.ink2)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(attributes.title)
                    .font(.system(.title3, design: .serif))
                    .lineLimit(2)
                Spacer(minLength: 0)
                HaloActivityTimer(start: attributes.startDate, end: state.endDate,
                                  remaining: state.pausedRemaining, phase: state.phase)
                    .font(.system(.largeTitle, design: .rounded).weight(.light))
                    .monospacedDigit()
                    .foregroundStyle(colors.accent)
                    .frame(maxWidth: 115)
            }

            if state.pausedRemaining == nil && state.phase != "finished" {
                ProgressView(timerInterval: attributes.startDate...max(attributes.startDate.addingTimeInterval(1), state.endDate), countsDown: false)
                    .tint(colors.accent)
            }

            if !attributes.isEvent && state.phase != "finished" {
                HStack {
                    Button(intent: PauseFocusIntent()) {
                        ActivityControlLabel(paused: state.pausedRemaining != nil)
                    }
                    Spacer()
                    Button(intent: EndFocusIntent()) { Label("End", systemImage: "stop.fill") }
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .tint(colors.accent)
            }
        }
        .padding(16)
        .foregroundStyle(colors.ink)
        .allowsHitTesting(interactive)
    }
}

struct HaloActivityTimer: View {
    var start: Date
    var end: Date
    var remaining: TimeInterval?
    var phase: String

    @ViewBuilder var body: some View {
        if phase == "finished" { Text("Done") }
        else if let remaining { Text(Duration.seconds(remaining), format: .time(pattern: .minuteSecond)) }
        else { Text(timerInterval: start...max(start.addingTimeInterval(1), end), countsDown: true) }
    }
}

struct ActivityControlLabel: View {
    var paused: Bool

    var body: some View {
        Label {
            Text(paused ? String(localized: "Resume") : String(localized: "Pause"))
        } icon: {
            Image(systemName: paused ? "play.fill" : "pause.fill")
                .contentTransition(.symbolEffect(.replace))
        }
    }
}

#Preview("Activity · Ruby") {
    let now = Date.now
    DesignPreview(themeID: "rubyGlass", scheme: .dark) {
        HaloActivityBanner(
            attributes: HaloActivityAttributes(title: "Deep work", startDate: now, endDate: now.addingTimeInterval(3000), themeId: "rubyGlass", accentColor: ThemeRegistry.theme("rubyGlass").dark.accent),
            state: .init(endDate: now.addingTimeInterval(3000)), interactive: false
        )
    }
}

#Preview("Activity · Gold Paused AX3") {
    let now = Date.now
    DesignPreview(themeID: "midnightGold", scheme: .dark, accessibility: true, reduceMotion: true) {
        HaloActivityBanner(
            attributes: HaloActivityAttributes(title: "Deep work", startDate: now, endDate: now.addingTimeInterval(3000), themeId: "midnightGold", accentColor: ThemeRegistry.theme("midnightGold").dark.accent),
            state: .init(endDate: now.addingTimeInterval(3000), pausedRemaining: 1800), interactive: false
        )
    }
}
