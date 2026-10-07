import SwiftUI
import AppIntents

/// Home Screen / StandBy sizes (points, 6.1-inch iPhone).
enum HomeFamily: String, CaseIterable, Sendable {
    case small, medium, large
    var size: CGSize {
        switch self {
        case .small: CGSize(width: 170, height: 170)
        case .medium: CGSize(width: 364, height: 170)
        case .large: CGSize(width: 364, height: 382)
        }
    }
}

extension WidgetKind {
    var homeFamilies: [HomeFamily] {
        switch self {
        case .orbit: [.small, .large]
        case .nextUp, .countdown: [.small]
        case .rhythm: [.medium, .large]
        case .rituals: [.small, .medium]
        case .month: [.medium]
        }
    }
}

/// A Home Screen / StandBy widget's content. The sky background comes from the caller
/// (`containerBackground` in WidgetKit, a `SkyBackground` in previews and tests).
struct HomeWidgetView: View {
    var kind: WidgetKind
    var family: HomeFamily
    var data: WidgetData
    var sky: SkyState
    var style: OrbitStyle
    var coordinate: GeoCoordinate
    var locked: Bool
    /// True inside WidgetKit, where ritual beads become `ToggleRitualIntent` buttons.
    var interactive = false
    /// False when iOS removes the sky behind the widget (StandBy, tinted or clear Home Screen).
    var backgroundVisible = true

    /// Ink for the widget: the sky's ink over the sky, light ink when the sky is gone (StandBy is dark).
    static func ink(for sky: SkyState, backgroundVisible: Bool) -> SkyColor { backgroundVisible ? sky.inkColor : SkyEngine.lightInk }

    /// The sky the content is drawn against: the real one, or a night sky when iOS removed it (StandBy is black),
    /// so rings, tracks and grids take light ink too.
    private var displaySky: SkyState {
        backgroundVisible ? sky : SkyEngine.state(sky: .celestial, at: data.date, coordinate: coordinate)
    }

    var body: some View {
        let ink = Self.ink(for: sky, backgroundVisible: backgroundVisible)
        GeometryReader { proxy in
            ZStack {
                content(proxy.size)
                    .blur(radius: locked ? 6 : 0)
                    .opacity(locked ? 0.35 : 1)
                if locked {
                    Label("Unlock in Halo Day", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .foregroundStyle(ink.color)
        .environment(\.colorScheme, ink == SkyEngine.lightInk ? .dark : .light)
    }

    /// Sizes follow the real content area, so the same layouts fit a 4.7-inch SE and a 6.9-inch Pro Max.
    @ViewBuilder
    private func content(_ size: CGSize) -> some View {
        switch (kind, family) {
        case (.orbit, .large): orbitLarge(size)
        case (.orbit, _): orbitSmall(size)
        case (.nextUp, _): nextUpSmall
        case (.rhythm, .large): rhythmLarge(size)
        case (.rhythm, _): rhythmMedium(size)
        case (.rituals, .medium): ritualsMedium(size)
        case (.rituals, _): ritualsSmall(size)
        case (.countdown, _): countdownSmall
        case (.month, _): monthMedium(size)
        }
    }

    // MARK: Pieces

    private var orbitContent: OrbitContent {
        let day = data.calendar.startOfDay(for: data.date)
        var content = data.orbit
        content.beads = DaySceneBuilder.beads(for: data.habits, on: day)
        content.nightSpans = OrbitGeometry.nightSpans(SolarCalculator.day(containing: day, coordinate: coordinate, calendar: data.calendar), calendar: data.calendar)
        content.moonPhase = SolarCalculator.moonPhase(at: data.date)
        return content
    }

    private func orbit(_ side: CGFloat) -> some View {
        OrbitCanvas(content: orbitContent, sky: displaySky, style: style).frame(width: side, height: side)
    }

    private func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }

    private func badge(_ event: CalendarEvent) -> String {
        if event.startDate <= data.date { return String(localized: "Now") }
        let minutes = Int(event.startDate.timeIntervalSince(data.date) / 60)
        return minutes < 90 ? String(localized: "In \(max(1, minutes)) min") : time(event.startDate)
    }

    private func row(_ event: CalendarEvent) -> some View {
        HStack(spacing: 8) {
            Circle().fill(OrbitPalette.eventColor(event.accentColor, sky: displaySky)).frame(width: 7, height: 7)
            Text(time(event.startDate)).font(.caption.monospacedDigit()).opacity(SkyEngine.secondaryOpacity)
            Text(event.title).font(.subheadline.weight(.medium)).lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private var sampleNote: some View {
        Group { if data.isSample { Text("Sample day").font(.caption2).opacity(SkyEngine.secondaryOpacity).lineLimit(1) } }
    }

    // MARK: Kinds

    private func orbitSmall(_ size: CGSize) -> some View {
        ZStack {
            orbit(min(size.width, size.height))
            VStack(spacing: 2) {
                Text(displaySky.moment.title).font(DS.Typeface.moment(13, relativeTo: .caption)).lineLimit(1).minimumScaleFactor(0.7)
                if !data.habits.isEmpty {
                    Text(verbatim: "\(data.ritualsDone)/\(data.habits.count)").font(.caption2.monospacedDigit()).opacity(SkyEngine.secondaryOpacity)
                }
                if data.isSample { Text("Sample").font(.caption2).opacity(SkyEngine.secondaryOpacity) }
            }
            .frame(width: min(size.width, size.height) * 0.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func orbitLarge(_ size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(data.date, format: .dateTime.weekday(.wide).day().month(.wide)).font(DS.Typeface.title(18, relativeTo: .headline))
                Spacer()
                Text(displaySky.moment.title).font(DS.Typeface.moment(14, relativeTo: .caption)).opacity(SkyEngine.secondaryOpacity)
            }
            orbit(min(size.width, size.height * 0.52)).frame(maxWidth: .infinity)
            let rows = data.upcoming(limit: size.height > 330 ? 3 : 2)
            if rows.isEmpty { Text("A clear day.").font(DS.Typeface.title(16)) }
            ForEach(rows) { row($0) }
            sampleNote
        }
    }

    private var nextUpSmall: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let event = data.nextEvent {
                Text(badge(event)).font(.caption.weight(.semibold)).opacity(SkyEngine.secondaryOpacity)
                Text(event.title).font(DS.Typeface.title(20, relativeTo: .headline)).lineLimit(2).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                sampleNote
                Text("\(time(event.startDate)) – \(time(event.endDate))").font(.caption.monospacedDigit())
                if let location = event.location { Text(location).font(.caption2).lineLimit(1).opacity(SkyEngine.secondaryOpacity) }
            } else {
                Text(data.date, format: .dateTime.weekday(.wide)).font(.caption.weight(.semibold)).opacity(SkyEngine.secondaryOpacity)
                Text("A clear day.").font(DS.Typeface.title(20, relativeTo: .headline))
                Spacer(minLength: 0)
                Text("Nothing else today").font(.caption).opacity(SkyEngine.secondaryOpacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rhythmMedium(_ size: CGSize) -> some View {
        HStack(spacing: 14) {
            orbit(min(size.height, size.width * 0.38))
            VStack(alignment: .leading, spacing: 6) {
                Text(data.date, format: .dateTime.weekday(.wide).day()).font(DS.Typeface.title(15, relativeTo: .headline))
                let rows = data.upcoming(limit: 4)
                if rows.isEmpty { Text("A clear day.").font(.subheadline) }
                ForEach(rows) { row($0) }
                Spacer(minLength: 0)
                sampleNote
            }
        }
    }

    private func rhythmLarge(_ size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(data.date, format: .dateTime.weekday(.wide).day().month(.wide)).font(DS.Typeface.title(18, relativeTo: .headline))
            orbit(min(size.width, size.height * 0.4)).frame(maxWidth: .infinity)
            let rows = data.upcoming(limit: size.height > 330 ? 5 : 4)
            if rows.isEmpty { Text("A clear day.").font(DS.Typeface.title(16)) }
            ForEach(rows) { row($0) }
            Spacer(minLength: 0)
            sampleNote
        }
    }

    private func bead(_ habit: Habit) -> some View {
        let done = habit.isCompleted(on: data.date)
        let color = (SkyColor(hexString: habit.accentColor) ?? .white).color
        return ZStack {
            Circle().fill(done ? color : .clear)
            Circle().strokeBorder(color, lineWidth: 2)
            Image(systemName: habit.icon).font(.system(size: 13, weight: .medium)).foregroundStyle(done ? Color.white : color)
        }
        .frame(width: 34, height: 34)
    }

    @ViewBuilder
    private func toggle(_ habit: Habit) -> some View {
        if interactive {
            Button(intent: ToggleRitualIntent(ritualID: habit.id.uuidString)) { bead(habit) }.buttonStyle(.plain)
        } else {
            bead(habit)
        }
    }

    private func ritualsSmall(_ size: CGSize) -> some View {
        VStack(spacing: 8) {
            AccessoryRitualRing(done: data.ritualsDone, total: data.habits.count).frame(width: size.height * 0.48, height: size.height * 0.48)
            if data.habits.isEmpty {
                Text("Add a ritual in Halo Day").font(.caption2).multilineTextAlignment(.center)
            } else {
                HStack(spacing: 8) { ForEach(data.habits.prefix(3)) { toggle($0) } }
            }
        }
    }

    private func ritualsMedium(_ size: CGSize) -> some View {
        HStack(spacing: 16) {
            AccessoryRitualRing(done: data.ritualsDone, total: data.habits.count).frame(width: size.height * 0.62, height: size.height * 0.62)
            VStack(alignment: .leading, spacing: 8) {
                if data.habits.isEmpty { Text("Add a ritual in Halo Day").font(.subheadline) }
                ForEach(data.habits.prefix(4)) { habit in
                    HStack(spacing: 10) {
                        toggle(habit)
                        Text(habit.title).font(.subheadline.weight(.medium)).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var countdownSmall: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let countdown = data.countdown, let days = data.countdownDays {
                Text(verbatim: "\(days)").font(DS.Typeface.clock(54)).minimumScaleFactor(0.5).lineLimit(1)
                Text(verbatim: DaysLeft.string(days)).font(.caption.weight(.semibold))
                Spacer(minLength: 0)
                Text(countdown.title).font(DS.Typeface.title(17, relativeTo: .headline)).lineLimit(2)
                Text(countdown.targetDate, format: .dateTime.day().month(.wide)).font(.caption2).opacity(SkyEngine.secondaryOpacity)
            } else {
                Image(systemName: "hourglass").font(.title)
                Spacer(minLength: 0)
                Text("Add a countdown").font(DS.Typeface.title(17, relativeTo: .headline))
                Text("Birthdays, trips, launches.").font(.caption2).opacity(SkyEngine.secondaryOpacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func monthMedium(_ size: CGSize) -> some View {
        let month = data.monthProgress
        let rows = ZoomBuilder.month(containing: data.date, now: data.date, events: data.events, habits: data.habits, calendar: data.calendar)
        return HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(data.date, format: .dateTime.month(.wide)).font(DS.Typeface.title(20, relativeTo: .headline))
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(displaySky.inkColor.color.opacity(0.18))
                        Capsule().fill(OrbitPalette.ritualColor(sky: displaySky)).frame(width: max(4, proxy.size.width * month.fraction))
                    }
                }
                .frame(height: 5)
                Text("Day \(month.day) of \(month.daysInMonth)").font(.caption)
                Text(verbatim: DaysLeft.string(month.daysLeft)).font(.caption2).opacity(SkyEngine.secondaryOpacity)
            }
            .frame(width: size.width * 0.32)
            VStack(spacing: 2) {
                ForEach(rows.indices, id: \.self) { index in
                    HStack(spacing: 2) {
                        ForEach(0..<7, id: \.self) { column in
                            if let mini = rows[index][column] {
                                MiniOrbit(mini: mini, sky: displaySky, nowHour: mini.isToday ? OrbitGeometry.hours(of: data.date, calendar: data.calendar) : nil)
                                    .frame(width: cell(size, rows: rows.count), height: cell(size, rows: rows.count))
                            } else {
                                Color.clear.frame(width: cell(size, rows: rows.count), height: cell(size, rows: rows.count))
                            }
                        }
                    }
                }
            }
        }
    }

    private func cell(_ size: CGSize, rows: Int) -> CGFloat {
        min((size.width * 0.66 - 12) / 7, (size.height - 2 * CGFloat(rows)) / CGFloat(max(1, rows)))
    }
}
