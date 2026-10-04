import SwiftUI
import WidgetKit

/// The exact renderer is compiled into both targets. Accessory previews are
/// deliberately monochrome: iOS, not Halo Day, chooses Lock Screen widget tint.
struct HaloWidgetContent: View {
    var date: Date
    var type: WidgetType
    var size: WidgetSize
    var theme: HaloTheme
    var events: [CalendarEvent]
    var habits: [Habit]
    var focus: FocusSession?
    var countdown: Countdown?
    var sample = false
    var interactive = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.widgetRenderingMode) private var renderingMode
    private var accessory: Bool { size.isAccessory }
    private var monochrome: Bool { accessory || renderingMode != .fullColor }
    private var nextEvent: CalendarEvent? {
        events.filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) || ($0.startDate <= date && $0.endDate > date) }
            .sorted { $0.startDate < $1.startDate }.first { $0.endDate > date }
    }
    private var dayNumber: Int { Calendar.current.component(.day, from: date) }
    private var monthDays: Int { Calendar.current.range(of: .day, in: .month, for: date)!.count }
    private var completed: Int { habits.filter { $0.isCompleted(on: date) }.count }
    var body: some View {
        Group {
            switch size {
            case .inline: inline
            case .circular: circular
            case .rectangular: rectangular
            case .small, .medium, .large: home
            }
        }.foregroundStyle(monochrome ? Color.primary : Color(hex: theme.palette(scheme).ink))
            .tint(monochrome ? Color.primary : Color(hex: theme.palette(scheme).accent))
            .privacySensitive()
    }
    @ViewBuilder private var inline: some View {
        switch type {
        case .agenda:
            if let event = nextEvent { Text("Next: \(event.title) · \(event.startDate.formatted(date: .omitted, time: .shortened))") }
            else { Text("An open day") }
        case .month: Text("Day \(dayNumber)/\(monthDays) · \(monthDays - dayNumber) days left")
        case .habit, .ritual: Text("Rituals · \(completed)/\(habits.count) beautifully kept")
        case .focus:
            if let focus, focus.isActive { Text("Focus · \(focus.title)") } else { Text("Make space to focus") }
        case .countdown: countdownText
        case .week, .mini: Text(date, format: .dateTime.month(.abbreviated).day().weekday())
        }
    }
    private var circular: some View {
        ZStack {
            ProgressRing(progress: ringProgress, width: 4)
            VStack(spacing: 0) {
                if type == .habit {
                    Image(systemName: "flame").font(.caption)
                    Text(habits.first?.streak(asOf: date) ?? 0, format: .number).font(.title3.monospacedDigit())
                } else if type == .focus, let focus, focus.isActive {
                    Image(systemName: "timer").font(.caption)
                    if focus.isPaused { Text("Paused").font(.caption2) }
                    else if focus.endDate > date { Text(timerInterval: date...focus.endDate, countsDown: true).font(.caption.monospacedDigit()) }
                    else { Text("Done").font(.caption) }
                } else if type == .ritual {
                    Text("\(completed)/\(habits.count)").font(.headline)
                } else {
                    Text(date, format: .dateTime.month(.abbreviated)).font(.caption2)
                    Text(dayNumber, format: .number).font(.system(.title2, design: .rounded))
                }
            }
        }
    }
    private var ringProgress: Double {
        switch type {
        case .habit, .ritual: Double(completed) / Double(max(1, habits.count))
        case .focus: focus.map { 1 - $0.remaining(at: date) / Double($0.durationMinutes * 60) } ?? 0
        default: Double(dayNumber) / Double(monthDays)
        }
    }
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            switch type {
            case .agenda:
                Text(sample ? "SAMPLE AGENDA" : "TODAY").font(.caption2.bold()).widgetAccentable()
                let upcoming = events.filter { $0.endDate > date && Calendar.current.isDate($0.startDate, inSameDayAs: date) }.prefix(2)
                if upcoming.isEmpty { Text("An open day").font(.headline) }
                ForEach(Array(upcoming)) { event in
                    HStack {
                        Text(event.title).font(.caption).lineLimit(1)
                        Spacer(minLength: 2)
                        Text(event.startDate, style: .time).font(.caption.monospacedDigit())
                    }
                }
            case .month:
                Text(date, format: .dateTime.month(.wide)).font(.system(.headline, design: .serif))
                ProgressView(value: Double(dayNumber), total: Double(monthDays))
                Text("\(monthDays - dayNumber) days left").font(.caption)
            case .ritual, .habit:
                Text("Daily rituals").font(.headline)
                ForEach(habits.prefix(2)) { habit in
                    Label(habit.title, systemImage: habit.isCompleted(on: date) ? "checkmark.circle.fill" : habit.icon).font(.caption).lineLimit(1)
                }
            case .focus:
                Text(focus?.title ?? String(localized: "Make space to focus")).font(.headline).lineLimit(1)
                focusTimer
            case .countdown: countdownText.font(.headline)
            case .mini: Text(date, format: .dateTime.month(.wide).day()).font(.headline); weekRow
            case .week: weekRow
            }
        }
    }
    private var home: some View {
        VStack(alignment: .leading, spacing: HaloTokens.Space.small) {
            HStack {
                Text(date, format: .dateTime.month(.abbreviated).day()).font(.system(size == .small ? .title2 : .title, design: theme.widgetStyle == "technical" ? .rounded : .serif)).widgetAccentable()
                Spacer(minLength: 0)
                Image(systemName: "circle.dotted").foregroundStyle(.tint)
            }
            if sample { Text("Sample day").font(.caption2).foregroundStyle(.secondary) }
            switch type {
            case .agenda:
                if let event = nextEvent {
                    Text(event.startDate, style: .time).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    Text(event.title).font(.headline).lineLimit(2)
                } else { Text("An open day").font(.headline) }
                if size != .small { agendaRows }
            case .month:
                Spacer(minLength: 0)
                Text(Double(dayNumber) / Double(monthDays), format: .percent.precision(.fractionLength(0))).font(.system(.largeTitle, design: .rounded)).widgetAccentable()
                ProgressView(value: Double(dayNumber), total: Double(monthDays))
                Text("\(monthDays - dayNumber) days left").font(.caption)
            case .week: weekRow; if size != .small { agendaRows }
            case .mini:
                MiniMonthGrid(month: date, highlights: Set(events.filter { Calendar.current.isDate($0.startDate, equalTo: date, toGranularity: .month) }.map { Calendar.current.component(.day, from: $0.startDate) }))
            case .habit:
                Image(systemName: "flame").font(.title).foregroundStyle(.tint)
                Text(habits.first?.streak(asOf: date) ?? 0, format: .number).font(.system(.largeTitle, design: .rounded))
                Text("Day streak").font(.caption)
            case .ritual:
                ForEach(habits.prefix(size == .small ? 2 : 4)) { habit in
                    if interactive {
                        Button(intent: ToggleRitualIntent(ritualID: habit.id.uuidString)) {
                            ritualRow(habit)
                        }.buttonStyle(.plain)
                    } else { ritualRow(habit) }
                }
            case .focus:
                Text(focus?.title ?? String(localized: "Deep work")).font(.headline)
                focusTimer
                if let focus { ProgressView(value: 1 - focus.remaining(at: date) / Double(focus.durationMinutes * 60)) }
            case .countdown: countdownText.font(.system(.title2, design: .serif))
            }
            if size == .large {
                Divider(); Text("Your day, beautifully on display.").font(.caption).foregroundStyle(.secondary)
                if type != .agenda && type != .week { agendaRows }
                ForEach(habits.prefix(3)) { ritualRow($0) }
            }
            Spacer(minLength: 0)
        }
    }
    private func ritualRow(_ habit: Habit) -> some View {
        Label(habit.title, systemImage: habit.isCompleted(on: date) ? "checkmark.circle.fill" : "circle")
            .font(.caption).lineLimit(1).foregroundStyle(habit.isCompleted(on: date) ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
    }
    private var agendaRows: some View {
        ForEach(Array(events.filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) }.prefix(size == .large ? 5 : 2))) { event in
            HStack { Text(event.startDate, style: .time).font(.caption.monospacedDigit()); Text(event.title).font(.caption).lineLimit(1) }
        }
    }
    private var weekRow: some View {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: date)!.start
        return HStack(spacing: 3) {
            ForEach(0..<7) { offset in
                let day = calendar.date(byAdding: .day, value: offset, to: start)!
                VStack(spacing: 4) {
                    Text(day, format: .dateTime.weekday(.narrow)).font(.caption2)
                    Text(day, format: .dateTime.day()).font(.caption.monospacedDigit())
                }.frame(maxWidth: .infinity).opacity(calendar.isDate(day, inSameDayAs: date) ? 1 : 0.6)
            }
        }
    }
    @ViewBuilder private var focusTimer: some View {
        if let focus, focus.isActive {
            if let remaining = focus.pausedRemaining { Text(Duration.seconds(remaining), format: .time(pattern: .minuteSecond)).font(.title2.monospacedDigit()) }
            else if focus.endDate > date { Text(timerInterval: date...focus.endDate, countsDown: true).font(.title2.monospacedDigit()) }
            else { Text("Beautifully done.").font(.headline) }
        } else { Text("Choose a length and begin.").font(.caption) }
    }
    @ViewBuilder private var countdownText: some View {
        if let countdown {
            let days = max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: date), to: Calendar.current.startOfDay(for: countdown.targetDate)).day ?? 0)
            Text("\(days) days · \(countdown.title)")
        } else { Text("Count down to something") }
    }
}

struct PhonePreview: View {
    var preset: WidgetPreset
    var events: [CalendarEvent]
    var habits: [Habit]
    var focus: FocusSession?
    var countdown: Countdown?
    var date: Date = .now
    var sample = true
    var body: some View {
        let theme = ThemeRegistry.theme(preset.themeId)
        let palette = theme.light
        VStack(spacing: HaloTokens.Space.card) {
            Capsule().fill(Color(hex: palette.ink)).frame(width: 80, height: 23).padding(.top, HaloTokens.Space.small)
            Text(date, format: .dateTime.weekday(.wide).month(.abbreviated).day()).font(.caption)
            Text(date, format: .dateTime.hour().minute()).font(.system(size: 56, weight: .light, design: .rounded)).monospacedDigit()
            HaloWidgetContent(date: date, type: preset.widgetType, size: preset.widgetFamily, theme: theme, events: events, habits: habits, focus: focus, countdown: countdown, sample: sample)
                .frame(width: previewWidth, height: previewHeight, alignment: .topLeading)
                .padding(preset.widgetFamily.isAccessory ? 0 : HaloTokens.Space.row)
                .background(preset.widgetFamily.isAccessory ? Color.clear : Color(hex: palette.surface).opacity(0.85), in: RoundedRectangle(cornerRadius: HaloTokens.Radius.hero))
                .environment(\.colorScheme, theme.darkOnly ? .dark : .light)
            Spacer(minLength: HaloTokens.Space.major)
            HStack { Image(systemName: "flashlight.off.fill"); Spacer(); Image(systemName: "camera.fill") }.padding(HaloTokens.Space.hero)
        }.frame(width: 260, height: preset.widgetFamily == .large ? 580 : 430)
            .foregroundStyle(Color(hex: palette.ink))
            .background(Color(hex: palette.bg).overlay { RadialGradient(colors: [Color(hex: palette.halo), .clear], center: .top, startRadius: 0, endRadius: 340) })
            .clipShape(RoundedRectangle(cornerRadius: HaloTokens.Radius.phone))
            .overlay(RoundedRectangle(cornerRadius: HaloTokens.Radius.phone).stroke(Color(hex: palette.ink).opacity(0.2), lineWidth: 5))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Widget preview"))
    }
    private var previewWidth: CGFloat { preset.widgetFamily == .circular ? 64 : preset.widgetFamily == .small ? 140 : 220 }
    private var previewHeight: CGFloat {
        switch preset.widgetFamily { case .inline: 24; case .circular: 64; case .rectangular: 72; case .small: 140; case .medium: 145; case .large: 300 }
    }
}
