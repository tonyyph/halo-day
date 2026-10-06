import SwiftUI

/// The Live Activity on the Lock Screen: the focus-dusk sky, an Orbit-style ring that empties as time runs out,
/// the title and a self-updating timer. Shared so it can be rendered in tests.
struct FocusActivityView: View {
    var attributes: HaloActivityAttributes
    var state: HaloActivityAttributes.ContentState
    /// Fixed time for tests; nil uses the live clock (WidgetKit timers keep counting on their own).
    var now: Date?

    static func sky(for attributes: HaloActivityAttributes, at date: Date) -> SkyState {
        SkyEngine.focusDusk(SkyEngine.state(sky: SkyID(rawValue: attributes.themeId) ?? .livingSky, at: date,
                                            coordinate: TimeZoneLocator.approximateCoordinate(for: .current, at: date)))
    }

    var body: some View {
        let reference = now ?? attributes.startDate
        let sky = Self.sky(for: attributes, at: reference)
        HStack(spacing: 14) {
            FocusActivityRing(attributes: attributes, state: state, now: now, glow: OrbitPalette.ritualColor(sky: sky))
                .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption.weight(.semibold)).opacity(SkyEngine.secondaryOpacity)
                Text(attributes.title).font(DS.Typeface.title(17, relativeTo: .headline)).lineLimit(2).minimumScaleFactor(0.85)
                Text(detail).font(.caption).opacity(SkyEngine.secondaryOpacity)
            }
            Spacer(minLength: 8)
            FocusActivityTimer(attributes: attributes, state: state, now: now)
                .font(DS.Typeface.clock(30))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: 92, alignment: .trailing)
        }
        .padding(16)
        .foregroundStyle(sky.inkColor.color)
        .background { SkyBackground(state: sky) }
        .environment(\.colorScheme, .dark)
    }

    private var label: String {
        if attributes.isEvent { return String(localized: "Starts soon") }
        switch state.phase {
        case "finished": return String(localized: "Done")
        default: return state.pausedRemaining != nil ? String(localized: "Paused") : String(localized: "Focusing")
        }
    }

    private var detail: String {
        let time = state.endDate.formatted(date: .omitted, time: .shortened)
        return attributes.isEvent ? String(localized: "Starts at \(time)") : String(localized: "until \(time)")
    }
}

/// Remaining time as a ring: animates itself while running, frozen while paused, full when done.
struct FocusActivityRing: View {
    var attributes: HaloActivityAttributes
    var state: HaloActivityAttributes.ContentState
    var now: Date?
    var glow: Color

    var body: some View {
        ZStack {
            Circle().stroke(.primary.opacity(0.18), lineWidth: 5)
            if state.phase == "finished" {
                Circle().stroke(glow, lineWidth: 5)
                Image(systemName: "checkmark").font(.headline)
            } else if let remaining = state.pausedRemaining ?? now.map({ max(0, state.endDate.timeIntervalSince($0)) }) {
                // Paused, or a fixed time (tests/previews, where timer-driven views cannot render): a static ring.
                let total = max(1, state.endDate.timeIntervalSince(attributes.startDate))
                Circle().trim(from: 0, to: remaining / total)
                    .stroke(glow, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: state.pausedRemaining != nil ? "pause.fill" : attributes.isEvent ? "calendar" : "timer").font(.caption)
            } else {
                ProgressView(timerInterval: attributes.startDate...max(attributes.startDate.addingTimeInterval(1), state.endDate), countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    Image(systemName: attributes.isEvent ? "calendar" : "timer").font(.caption)
                }
                .progressViewStyle(.circular)
                .tint(glow)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The countdown text, or the frozen remaining time when paused.
struct FocusActivityTimer: View {
    var attributes: HaloActivityAttributes
    var state: HaloActivityAttributes.ContentState
    var now: Date? = nil

    var body: some View {
        if state.phase == "finished" {
            let minutes = max(1, Int(state.endDate.timeIntervalSince(attributes.startDate) / 60))
            Text(verbatim: "+\(minutes)′")
        } else if let remaining = state.pausedRemaining ?? now.map({ max(0, state.endDate.timeIntervalSince($0)) }) {
            Text(Duration.seconds(remaining), format: .time(pattern: .minuteSecond))
        } else {
            Text(timerInterval: Date.now...max(Date.now, state.endDate), countsDown: true)
        }
    }
}
