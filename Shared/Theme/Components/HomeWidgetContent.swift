import SwiftUI
import WidgetKit

struct HomeWidgetContent: View {
    let date: Date
    let type: WidgetType
    let size: WidgetSize
    let data: WidgetPresentation
    let style: WidgetStyle
    let habits: [Habit]
    let focus: FocusSession?
    let countdown: Countdown?
    let sample: Bool
    let interactive: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        Group {
            if type == .agenda && size == .medium { mediumAgenda }
            else if type == .agenda && size == .large { largeAgenda }
            else if type == .ritual && size == .medium { ritualDashboard }
            else { compactDashboard }
        }
    }

    private var dateHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(date, format: .dateTime.weekday(.wide))
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(palette.accentInk)
                .widgetAccentable()
            Spacer(minLength: 0)
            Image(systemName: "circle.dotted").font(.caption).foregroundStyle(palette.accent).widgetAccentable()
        }
    }

    private var mediumAgenda: some View {
        GeometryReader { proxy in
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(date, format: .dateTime.weekday(.wide))
                        .font(.caption2.weight(.semibold)).textCase(.uppercase).widgetAccentable()
                    Text(date, format: .dateTime.day().month(.abbreviated))
                        .font(.system(.title2, design: style.numeralDesign)).fontWeight(style.numeralWeight)
                    Spacer(minLength: 0)
                    ProgressView(value: data.monthProgress).widgetAccentable()
                    ritualDots
                }
                .frame(width: max(60, proxy.size.width * 0.36), alignment: .leading)
                if style.separator == .hairline { Rectangle().fill(palette.hairline).frame(width: 0.5) }
                VStack(alignment: .leading, spacing: 10) {
                    WidgetAgendaRows(events: Array(data.upcoming.prefix(3)), date: date, style: style)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var largeAgenda: some View {
        VStack(alignment: .leading, spacing: 12) {
            dateHeader
            Text(date, format: .dateTime.day().month(.wide))
                .font(.system(.title, design: style.titleDesign))
            WidgetWeekStrip(days: data.week, style: style)
            if style.separator == .hairline { Divider() }
            WidgetAgendaRows(events: Array(data.todayEvents.prefix(6)), date: date, style: style)
            Spacer(minLength: 0)
            HStack {
                ProgressView(value: data.monthProgress).widgetAccentable()
                Text(data.monthProgress, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.monospacedDigit()).contentTransition(.numericText())
            }
        }
    }

    private var compactDashboard: some View {
        VStack(alignment: .leading, spacing: 5) {
            if type == .mini {
                Text(date, format: .dateTime.month(.wide))
                    .font(.system(.headline, design: style.titleDesign)).widgetAccentable()
            } else { dateHeader }

            switch type {
            case .agenda:
                Text(data.day, format: .number)
                    .font(.system(.largeTitle, design: style.numeralDesign))
                    .fontWeight(style.numeralWeight).monospacedDigit()
                    .contentTransition(.numericText())
                if let event = data.next {
                    HStack(spacing: 6) {
                        WidgetNowMarker(style: style.nowMarker)
                        Text(event.title).font(.headline).lineLimit(1).privacySensitive()
                    }
                    Text(event.startDate, style: .time).font(.caption.monospacedDigit()).foregroundStyle(palette.ink2)
                    if data.todayEvents.count > 1 {
                        Text("+\(data.todayEvents.count - 1) more today").font(.caption2).foregroundStyle(palette.ink3)
                    }
                } else { Text("An open day").font(.headline) }
            case .month:
                Spacer(minLength: 0)
                Text(data.monthProgress, format: .percent.precision(.fractionLength(0)))
                    .font(.system(.largeTitle, design: style.numeralDesign)).fontWeight(style.numeralWeight)
                    .contentTransition(.numericText()).widgetAccentable()
                Text("\(data.daysLeft) days left").font(.caption).foregroundStyle(palette.ink2)
                ProgressView(value: data.monthProgress).widgetAccentable()
            case .week:
                WidgetWeekStrip(days: data.week, style: style)
                WidgetAgendaRows(events: Array(data.upcoming.prefix(2)), date: date, style: style)
            case .mini:
                MiniMonthGrid(month: date, highlights: data.monthHighlights)
                if size == .large {
                    Divider()
                    WidgetAgendaRows(events: Array(data.upcoming.prefix(3)), date: date, style: style)
                }
            case .habit:
                Image(systemName: "sparkle").font(.title2).foregroundStyle(palette.accent).widgetAccentable()
                Text(data.streak, format: .number)
                    .font(.system(.largeTitle, design: style.numeralDesign)).fontWeight(style.numeralWeight)
                    .contentTransition(.numericText())
                Text("Day streak").font(.caption).foregroundStyle(palette.ink2)
            case .ritual:
                Text("\(data.completed)/\(habits.count)").font(.title3.monospacedDigit()).contentTransition(.numericText())
                ForEach(habits.prefix(2)) { habit in
                    Label(habit.title, systemImage: habit.isCompleted(on: date) ? "checkmark.circle.fill" : habit.icon)
                        .font(.caption).lineLimit(1)
                }
            case .focus:
                Text(focus?.title ?? String(localized: "Deep work"))
                    .font(.system(.headline, design: style.titleDesign)).lineLimit(1)
                WidgetFocusTimer(focus: focus, date: date)
                    .font(.system(.largeTitle, design: style.numeralDesign)).monospacedDigit()
                if let focus, focus.isActive, !focus.isPaused, focus.endDate > date {
                    ProgressView(timerInterval: focus.startDate...focus.endDate, countsDown: false).widgetAccentable()
                } else { Text("Make space to focus").font(.caption).foregroundStyle(palette.ink2) }
            case .countdown:
                Text(data.countdownDays, format: .number)
                    .font(.system(.largeTitle, design: style.numeralDesign)).fontWeight(style.numeralWeight)
                    .contentTransition(.numericText()).widgetAccentable()
                Text(countdown?.title ?? String(localized: "Count down to something"))
                    .font(.headline).lineLimit(2)
                Text("DAYS").font(.caption2).foregroundStyle(palette.ink2)
            }
            Spacer(minLength: 0)
        }
    }

    private var ritualDashboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily rituals").font(.system(.headline, design: style.titleDesign))
                Spacer(minLength: 0)
                Text("\(data.completed)/\(habits.count)").font(.caption.monospacedDigit()).contentTransition(.numericText())
            }
            HStack(alignment: .top, spacing: 8) {
                ForEach(habits.prefix(4)) { habit in
                    if interactive {
                        Button(intent: ToggleRitualIntent(ritualID: habit.id.uuidString)) { ritualTile(habit) }
                            .buttonStyle(.plain)
                            .invalidatableContent()
                    } else { ritualTile(habit) }
                }
            }
        }
    }

    private func ritualTile(_ habit: Habit) -> some View {
        VStack(spacing: 7) {
            Image(systemName: habit.isCompleted(on: date) ? "checkmark" : habit.icon)
                .font(.title3)
                .foregroundStyle(habit.isCompleted(on: date) ? palette.accentOn : palette.accentInk)
                .frame(width: 38, height: 38)
                .background(habit.isCompleted(on: date) ? palette.accent : palette.accentSoft, in: Circle())
                .widgetAccentable()
            Text(habit.title).font(.caption2).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(Text(habit.title))
    }

    private var ritualDots: some View {
        HStack(spacing: 4) {
            ForEach(habits.prefix(5)) { habit in
                Circle().fill(habit.isCompleted(on: date) ? palette.accent : palette.hairline)
                    .frame(width: 5, height: 5).widgetAccentable()
            }
        }
    }
}

#Preview("Home · Small Light") {
    DesignPreview {
        HaloWidgetContent(date: .now, type: .agenda, size: .small, theme: ThemeRegistry.all[0], events: MockData.events(), habits: MockData.habits, focus: nil, countdown: nil)
            .frame(width: 140, height: 140)
    }
}

#Preview("Home · Medium Ruby Dark") {
    DesignPreview(themeID: "rubyGlass", scheme: .dark) {
        HaloWidgetContent(date: .now, type: .agenda, size: .medium, theme: ThemeRegistry.theme("rubyGlass"), events: MockData.events(), habits: MockData.habits, focus: nil, countdown: nil)
            .frame(width: 300, height: 140)
    }
}

#Preview("Home · Large Gold Empty AX3") {
    DesignPreview(themeID: "midnightGold", scheme: .dark, accessibility: true, reduceMotion: true) {
        HaloWidgetContent(date: .now, type: .agenda, size: .large, theme: ThemeRegistry.theme("midnightGold"), events: [], habits: [], focus: nil, countdown: nil)
            .frame(width: 300, height: 310)
    }
}
