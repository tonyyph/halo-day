import SwiftUI

/// The Live Activity on the Lock Screen: the focus-dusk sky, an Orbit-style ring that empties as time runs out,
/// the title and a self-updating timer. Shared so it can be rendered in tests.
struct FocusActivityView: View {
    var attributes: HaloActivityAttributes
    var state: HaloActivityAttributes.ContentState
    /// Fixed time for tests; nil uses the live clock (WidgetKit timers keep counting on their own).
    var now: Date?
    /// ActivityKit marks the activity stale at its end date even if the app never got to update it.
    var isStale = false

    enum DisplayPhase: Equatable { case running, paused, finished, upcoming, started }

    static func phase(attributes: HaloActivityAttributes, state: HaloActivityAttributes.ContentState, isStale: Bool) -> DisplayPhase {
        if attributes.isEvent { return isStale ? .started : .upcoming }
        if state.phase == "finished" || isStale { return .finished }
        return state.pausedRemaining != nil ? .paused : .running
    }

    /// The ring measures against the planned length (attributes start→end), ending at the current end date,
    /// so time spent paused never stretches it.
    static func ringInterval(attributes: HaloActivityAttributes, state: HaloActivityAttributes.ContentState) -> ClosedRange<Date> {
        let planned = max(1, attributes.endDate.timeIntervalSince(attributes.startDate))
        return state.endDate.addingTimeInterval(-planned)...state.endDate
    }

    static func sky(for attributes: HaloActivityAttributes, at date: Date) -> SkyState {
        SkyEngine.focusDusk(SkyEngine.state(sky: SkyID(rawValue: attributes.themeId) ?? .livingSky, at: date,
                                            coordinate: TimeZoneLocator.approximateCoordinate(for: .current, at: date)))
    }

    var body: some View {
        let reference = now ?? attributes.startDate
        let sky = Self.sky(for: attributes, at: reference)
        HStack(spacing: 14) {
            FocusActivityRing(attributes: attributes, state: state, now: now, isStale: isStale, glow: OrbitPalette.ritualColor(sky: sky))
                .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption.weight(.semibold)).opacity(SkyEngine.secondaryOpacity)
                Text(attributes.title).font(DS.Typeface.title(17, relativeTo: .headline)).lineLimit(2).minimumScaleFactor(0.85)
                Text(detail).font(.caption).opacity(SkyEngine.secondaryOpacity)
            }
            Spacer(minLength: 8)
            FocusActivityTimer(attributes: attributes, state: state, now: now, isStale: isStale)
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
        switch Self.phase(attributes: attributes, state: state, isStale: isStale) {
        case .upcoming: String(localized: "Starts soon")
        case .started: String(localized: "Now")
        case .finished: String(localized: "Done")
        case .paused: String(localized: "Paused")
        case .running: String(localized: "Focusing")
        }
    }

    private var detail: String {
        let time = state.endDate.formatted(date: .omitted, time: .shortened)
        switch Self.phase(attributes: attributes, state: state, isStale: isStale) {
        case .upcoming, .started: return String(localized: "Starts at \(time)")
        case .paused: return String(localized: "Resume when you're ready")
        case .finished: return String(localized: "Time well spent.")
        case .running: return String(localized: "until \(time)")
        }
    }
}

/// Remaining time as a ring: animates itself while running, frozen while paused, full when done.
struct FocusActivityRing: View {
    var attributes: HaloActivityAttributes
    var state: HaloActivityAttributes.ContentState
    var now: Date?
    var isStale = false
    var glow: Color

    var body: some View {
        let phase = FocusActivityView.phase(attributes: attributes, state: state, isStale: isStale)
        let interval = FocusActivityView.ringInterval(attributes: attributes, state: state)
        let planned = interval.upperBound.timeIntervalSince(interval.lowerBound)
        ZStack {
            Circle().stroke(.primary.opacity(0.18), lineWidth: 5)
            if phase == .finished || phase == .started {
                Circle().stroke(glow, lineWidth: 5)
                Image(systemName: "checkmark").font(.headline)
            } else if let remaining = state.pausedRemaining ?? now.map({ max(0, state.endDate.timeIntervalSince($0)) }) {
                // Paused, or a fixed time (tests/previews, where timer-driven views cannot render): a static ring.
                Circle().trim(from: 0, to: min(1, remaining / planned))
                    .stroke(glow, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: state.pausedRemaining != nil ? "pause.fill" : attributes.isEvent ? "calendar" : "timer").font(.caption)
            } else {
                ProgressView(timerInterval: interval, countsDown: true) {
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
    var isStale = false

    var body: some View {
        let phase = FocusActivityView.phase(attributes: attributes, state: state, isStale: isStale)
        if phase == .started {
            Text(verbatim: state.endDate.formatted(date: .omitted, time: .shortened))
        } else if phase == .finished {
            let minutes = max(1, Int(state.endDate.timeIntervalSince(attributes.startDate) / 60))
            Text(verbatim: "+\(minutes)′")
        } else if let remaining = state.pausedRemaining ?? now.map({ max(0, state.endDate.timeIntervalSince($0)) }) {
            Text(Duration.seconds(remaining), format: .time(pattern: .minuteSecond))
        } else {
            Text(timerInterval: Date.now...max(Date.now, state.endDate), countsDown: true)
        }
    }
}
