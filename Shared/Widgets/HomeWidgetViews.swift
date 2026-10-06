import SwiftUI
import AppIntents

/// Home Screen / StandBy sizes (points, 6.1" iPhone).
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

    var body: some View {
        ZStack {
            content
                .blur(radius: locked ? 6 : 0)
                .opacity(locked ? 0.35 : 1)
            if locked {
                Label("Unlock in Halo Day", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(sky.inkColor.color)
        .environment(\.colorScheme, sky.ink == .light ? .dark : .light)
    }

    @ViewBuilder
    private var content: some View {
        switch (kind, family) {
        case (.orbit, .large): orbitLarge
        case (.orbit, _): orbitSmall
        case (.nextUp, _): nextUpSmall
        case (.rhythm, .large): rhythmLarge
        case (.rhythm, _): rhythmMedium
        case (.rituals, .medium): ritualsMedium
        case (.rituals, _): ritualsSmall
        case (.countdown, _): countdownSmall
        case (.month, _): monthMedium
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
        OrbitCanvas(content: orbitContent, sky: sky, style: style).frame(width: side, height: side)
    }

    private func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }

    private func badge(_ event: CalendarEvent) -> String {
        if event.startDate <= data.date { return String(localized: "Now") }
        let minutes = Int(event.startDate.timeIntervalSince(data.date) / 60)
        return minutes < 90 ? String(localized: "In \(max(1, minutes)) min") : time(event.startDate)
    }

    private func row(_ event: CalendarEvent) -> some View {
        HStack(spacing: 8) {
            Circle().fill(OrbitPalette.eventColor(event.accentColor, sky: sky)).frame(width: 7, height: 7)
            Text(time(event.startDate)).font(.caption.monospacedDigit()).opacity(SkyEngine.secondaryOpacity)
            Text(event.title).font(.subheadline.weight(.medium)).lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private var sampleNote: some View {
        Group { if data.isSample { Text("Sample day").font(.caption2).opacity(SkyEngine.secondaryOpacity) } }
    }

    // MARK: Kinds

    private var orbitSmall: some View {
        ZStack {
            orbit(150)
            VStack(spacing: 2) {
                Text(sky.moment.title).font(DS.Typeface.moment(13, relativeTo: .caption))
                if !data.habits.isEmpty {
                    Text(verbatim: "\(data.ritualsDone)/\(data.habits.count)").font(.caption2.monospacedDigit()).opacity(SkyEngine.secondaryOpacity)
                }
            }
        }
    }

    private var orbitLarge: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(data.date, format: .dateTime.weekday(.wide).day().month(.wide)).font(DS.Typeface.title(18, relativeTo: .headline))
                Spacer()
                Text(sky.moment.title).font(DS.Typeface.moment(14, relativeTo: .caption)).opacity(SkyEngine.secondaryOpacity)
            }
            orbit(200).frame(maxWidth: .infinity)
            let rows = data.upcoming(limit: 3)
            if rows.isEmpty { Text("A clear day.").font(DS.Typeface.title(16)) }
            ForEach(rows) { row($0) }
            sampleNote
        }
    }

    private var nextUpSmall: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let event = data.nextEvent {
                Text(badge(event)).font(.caption.weight(.semibold)).opacity(SkyEngine.secondaryOpacity)
                Text(event.title).font(DS.Typeface.title(20, relativeTo: .headline)).lineLimit(2)
                Spacer(minLength: 0)
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

    private var rhythmMedium: some View {
        HStack(spacing: 14) {
            orbit(130)
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

    private var rhythmLarge: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(data.date, format: .dateTime.weekday(.wide).day().month(.wide)).font(DS.Typeface.title(18, relativeTo: .headline))
            orbit(160).frame(maxWidth: .infinity)
            let rows = data.upcoming(limit: 6)
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

    private var ritualsSmall: some View {
        VStack(spacing: 10) {
            AccessoryRitualRing(done: data.ritualsDone, total: data.habits.count).frame(width: 74, height: 74)
            if data.habits.isEmpty {
                Text("Add a ritual in Halo Day").font(.caption2).multilineTextAlignment(.center)
            } else {
                HStack(spacing: 8) { ForEach(data.habits.prefix(3)) { toggle($0) } }
            }
        }
    }

    private var ritualsMedium: some View {
        HStack(spacing: 16) {
            AccessoryRitualRing(done: data.ritualsDone, total: data.habits.count).frame(width: 90, height: 90)
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
                Text("\(days) days left").font(.caption.weight(.semibold))
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

    private var monthMedium: some View {
        let month = data.monthProgress
        let rows = ZoomBuilder.month(containing: data.date, now: data.date, events: data.events, habits: data.habits, calendar: data.calendar)
        return HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(data.date, format: .dateTime.month(.wide)).font(DS.Typeface.title(20, relativeTo: .headline))
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(sky.inkColor.color.opacity(0.18))
                        Capsule().fill(OrbitPalette.ritualColor(sky: sky)).frame(width: max(4, proxy.size.width * month.fraction))
                    }
                }
                .frame(height: 5)
                Text("Day \(month.day) of \(month.daysInMonth)").font(.caption)
                Text("\(month.daysLeft) days left").font(.caption2).opacity(SkyEngine.secondaryOpacity)
            }
            .frame(width: 110)
            VStack(spacing: 2) {
                ForEach(rows.indices, id: \.self) { index in
                    HStack(spacing: 2) {
                        ForEach(0..<7, id: \.self) { column in
                            if let mini = rows[index][column] {
                                MiniOrbit(mini: mini, sky: sky, nowHour: mini.isToday ? OrbitGeometry.hours(of: data.date, calendar: data.calendar) : nil)
                                    .frame(width: 22, height: 22)
                            } else {
                                Color.clear.frame(width: 22, height: 22)
                            }
                        }
                    }
                }
            }
        }
    }
}
