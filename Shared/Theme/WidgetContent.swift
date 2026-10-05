import SwiftUI
import WidgetKit

/// Shared by WidgetKit and the in-app studio. Accessory previews are monochrome.
struct HaloWidgetContent: View {
    let date: Date
    let type: WidgetType
    let size: WidgetSize
    let theme: HaloTheme
    let habits: [Habit]
    let focus: FocusSession?
    let countdown: Countdown?
    let sample: Bool
    let interactive: Bool
    private let data: WidgetPresentation
    private let style: WidgetStyle
    @Environment(\.colorScheme) private var scheme
    @Environment(\.widgetRenderingMode) private var renderingMode

    init(date: Date, type: WidgetType, size: WidgetSize, theme: HaloTheme, events: [CalendarEvent], habits: [Habit], focus: FocusSession?, countdown: Countdown?, sample: Bool = false, interactive: Bool = false) {
        self.date = date; self.type = type; self.size = size; self.theme = theme
        self.habits = habits; self.focus = focus; self.countdown = countdown
        self.sample = sample; self.interactive = interactive
        data = WidgetPresentation(date: date, events: events, habits: habits, focus: focus, countdown: countdown)
        style = WidgetStyle(theme: theme)
    }

    private var monochrome: Bool { size.isAccessory || renderingMode != .fullColor }

    var body: some View {
        Group {
            switch size {
            case .inline: inline
            case .circular: circular
            case .rectangular: rectangular
            case .small, .medium, .large:
                HomeWidgetContent(date: date, type: type, size: size, data: data, style: style,
                                  habits: habits, focus: focus, countdown: countdown, sample: sample, interactive: interactive)
            }
        }
        .foregroundStyle(monochrome ? Color.primary : PaletteResolver.resolve(theme, scheme: scheme).ink)
        .tint(monochrome ? Color.primary : PaletteResolver.resolve(theme, scheme: scheme).accent)
        .environment(\.palette, monochrome ? PaletteResolver.vibrant(scheme) : PaletteResolver.resolve(theme, scheme: scheme))
        .accessibilityElement(children: interactive || size == .medium || size == .large ? .contain : .combine)
        .accessibilityLabel(Text(LocalizedStringKey(type.title)))
    }

    @ViewBuilder private var inline: some View {
        switch type {
        case .agenda:
            if let event = data.next { Text("Next: \(event.title) · \(data.nextTime)").privacySensitive() }
            else { Text("An open day") }
        case .month:
            Text("Day \(data.day)/\(data.monthDays) · \(data.daysLeft) days left")
        case .habit, .ritual:
            Text("Rituals · \(data.completed)/\(habits.count) beautifully kept")
        case .focus:
            if let focus, focus.isActive { Text("Focus · \(focus.title)") }
            else { Text("Make space to focus") }
        case .countdown:
            if let countdown { Text("\(data.countdownDays) days · \(countdown.title)") }
            else { Text("Count down to something") }
        case .week, .mini:
            Text(date, format: .dateTime.month(.abbreviated).day().weekday())
        }
    }

    private var circular: some View {
        ZStack {
            if style.lockScreenBackground { AccessoryWidgetBackground() }
            if type != .countdown {
                ProgressRing(progress: ringProgress, width: 4, segments: type == .ritual ? max(1, min(6, habits.count)) : 1)
                    .widgetAccentable()
            }
            VStack(spacing: 0) {
                switch type {
                case .habit:
                    Image(systemName: "sparkle").font(.caption2)
                    Text(data.streak, format: .number).font(.system(.title3, design: style.numeralDesign))
                        .contentTransition(.numericText())
                case .ritual:
                    Text("\(data.completed)/\(habits.count)").font(.headline).monospacedDigit()
                        .contentTransition(.numericText())
                case .focus:
                    Image(systemName: "timer").font(.caption2)
                    WidgetFocusTimer(focus: focus, date: date).font(.caption.monospacedDigit()).lineLimit(1)
                case .countdown:
                    if data.countdownDays > 99 { Text("\(data.countdownMonths) mo").font(.caption) }
                    else { Text(data.countdownDays, format: .number).font(.title3.monospacedDigit()) }
                    Text("DAYS").font(.caption2)
                default:
                    Text(data.day, format: .number).font(.system(.title2, design: style.numeralDesign)).fontWeight(style.numeralWeight)
                    Text(date, format: .dateTime.month(.abbreviated)).font(.caption2).textCase(.uppercase)
                }
            }
            .padding(5)
            .minimumScaleFactor(0.65)
        }
    }

    private var ringProgress: Double {
        switch type {
        case .habit, .ritual: data.ritualProgress
        case .focus: data.focusProgress
        default: data.monthProgress
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch type {
            case .agenda:
                if let event = data.next {
                    HStack(spacing: 6) {
                        WidgetNowMarker(style: style.nowMarker)
                        Text(event.title).font(.system(.headline, design: style.titleDesign)).lineLimit(1).privacySensitive()
                    }
                    HStack(spacing: 3) {
                        Text(event.startDate, style: .time)
                        Text("–")
                        Text(event.endDate, style: .time)
                    }
                    .font(.caption.monospacedDigit()).opacity(0.6)
                    if let next = data.upcoming.dropFirst().first {
                        HStack(spacing: 6) {
                            Text(next.startDate, style: .time).monospacedDigit()
                            Text(next.title).lineLimit(1).privacySensitive()
                        }
                        .font(.caption).opacity(0.6)
                        .transition(.push(from: .bottom))
                    }
                } else { Text("An open day").font(.system(.headline, design: style.titleDesign)) }
            case .month:
                HStack {
                    Text(date, format: .dateTime.month(.wide)).font(.system(.headline, design: style.titleDesign))
                    Spacer(minLength: 0)
                    Text(data.monthProgress, format: .percent.precision(.fractionLength(0))).font(.caption.monospacedDigit())
                        .contentTransition(.numericText())
                }
                ProgressView(value: data.monthProgress).widgetAccentable()
                Text("\(data.daysLeft) days left").font(.caption).opacity(0.6)
            case .ritual, .habit:
                HStack {
                    Text("Daily rituals").font(.headline)
                    Spacer(minLength: 0)
                    Text("\(data.completed)/\(habits.count)").font(.caption.monospacedDigit()).contentTransition(.numericText())
                }
                ForEach(habits.prefix(2)) { habit in
                    Label(habit.title, systemImage: habit.isCompleted(on: date) ? "checkmark.circle.fill" : habit.icon)
                        .font(.caption).lineLimit(1).opacity(habit.isCompleted(on: date) ? 1 : 0.6)
                }
            case .focus:
                Label(focus?.title ?? String(localized: "Make space to focus"), systemImage: "timer")
                    .font(.headline).lineLimit(1)
                WidgetFocusTimer(focus: focus, date: date).font(.system(.title2, design: style.numeralDesign)).monospacedDigit()
                if let focus, focus.isActive, !focus.isPaused, focus.endDate > date {
                    ProgressView(timerInterval: focus.startDate...focus.endDate, countsDown: false).widgetAccentable()
                }
            case .countdown:
                if let countdown {
                    Text(countdown.title).font(.system(.headline, design: style.titleDesign)).lineLimit(1)
                    Text("\(data.countdownDays) days").font(.title2.monospacedDigit()).contentTransition(.numericText())
                } else { Text("Count down to something").font(.headline) }
            case .week, .mini:
                WidgetWeekStrip(days: data.week, style: style)
            }
        }
    }
}

struct WidgetFocusTimer: View {
    var focus: FocusSession?
    var date: Date
    @ViewBuilder var body: some View {
        if let focus, focus.isActive {
            if let remaining = focus.pausedRemaining { Text(Duration.seconds(remaining), format: .time(pattern: .minuteSecond)) }
            else if focus.endDate > date { Text(timerInterval: focus.startDate...focus.endDate, countsDown: true) }
            else { Text("Done") }
        } else { Text("50") }
    }
}

struct WidgetNowMarker: View {
    var style: WidgetStyle.Marker
    @Environment(\.palette) private var palette
    var body: some View {
        Group {
            switch style {
            case .bar: Capsule().fill(palette.accent).frame(width: 3, height: 17)
            case .dot: Circle().fill(palette.accent).frame(width: 5, height: 5)
            case .ring: Circle().stroke(palette.accent, lineWidth: 1.5).frame(width: 6, height: 6)
            }
        }.widgetAccentable()
    }
}

#Preview("Accessories · Pearl") {
    DesignPreview {
        VStack(spacing: 24) {
            HaloWidgetContent(date: .now, type: .month, size: .inline, theme: ThemeRegistry.all[0], events: MockData.events(), habits: MockData.habits, focus: nil, countdown: nil)
            HaloWidgetContent(date: .now, type: .ritual, size: .circular, theme: ThemeRegistry.all[0], events: [], habits: MockData.habits, focus: nil, countdown: nil).frame(width: 72, height: 72)
            HaloWidgetContent(date: .now, type: .agenda, size: .rectangular, theme: ThemeRegistry.all[0], events: MockData.events(), habits: [], focus: nil, countdown: nil).frame(height: 76)
        }
    }
}

#Preview("Accessories · Gold Empty AX3") {
    DesignPreview(themeID: "midnightGold", scheme: .dark, accessibility: true, reduceMotion: true) {
        HaloWidgetContent(date: .now, type: .agenda, size: .rectangular, theme: ThemeRegistry.theme("midnightGold"), events: [], habits: [], focus: nil, countdown: nil)
    }
}
