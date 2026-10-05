import SwiftUI
import WidgetKit

struct WidgetStyle {
    enum Separator { case none, hairline, dot }
    enum Marker { case dot, bar, ring }
    let numeralDesign: Font.Design
    let numeralWeight: Font.Weight
    let titleDesign: Font.Design
    let italicDays: Bool
    let separator: Separator
    let nowMarker: Marker
    let rows: Int
    let lockScreenBackground: Bool

    init(theme: HaloTheme) {
        let name = theme.widgetStyle
        numeralDesign = ["editorial", "atelier", "minimal", "gilded"].contains(name) ? .serif : .rounded
        numeralWeight = name == "technical" ? .medium : name == "airy" ? .ultraLight : .light
        titleDesign = name == "technical" ? .default : .serif
        italicDays = name == "atelier"
        separator = ["airy", "editorial", "gilded"].contains(name) ? .hairline : ["organic", "atelier"].contains(name) ? .dot : .none
        nowMarker = ["glass", "technical", "minimal"].contains(name) ? .bar : ["organic", "gilded"].contains(name) ? .ring : .dot
        rows = ["airy", "atelier", "minimal"].contains(name) ? 2 : 3
        lockScreenBackground = ["glass", "technical", "organic", "gilded"].contains(name)
    }
}

struct WidgetPresentation {
    struct Day: Identifiable {
        let date: Date
        let eventCount: Int
        let today: Bool
        var id: Date { date }
    }

    let day: Int
    let monthDays: Int
    let monthProgress: Double
    let daysLeft: Int
    let completed: Int
    let ritualProgress: Double
    let streak: Int
    let todayEvents: [CalendarEvent]
    let upcoming: [CalendarEvent]
    let next: CalendarEvent?
    let nextTime: String
    let week: [Day]
    let monthHighlights: Set<Int>
    let countdownDays: Int
    let countdownMonths: Int
    let focusProgress: Double

    init(date: Date, events: [CalendarEvent], habits: [Habit], focus: FocusSession?, countdown: Countdown?) {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .day, for: date)!
        day = calendar.component(.day, from: date)
        monthDays = calendar.range(of: .day, in: .month, for: date)!.count
        monthProgress = Double(day) / Double(monthDays)
        daysLeft = monthDays - day
        completed = habits.filter { $0.isCompleted(on: date) }.count
        ritualProgress = Double(completed) / Double(max(1, habits.count))
        streak = habits.first?.streak(asOf: date) ?? 0
        todayEvents = events.filter { $0.startDate < interval.end && $0.endDate > interval.start }
        upcoming = todayEvents.filter { $0.endDate > date && !$0.isAllDay }
        next = upcoming.first
        nextTime = next?.startDate.formatted(.dateTime.hour().minute()) ?? ""
        var dayCounts: [Date: Int] = [:]
        for event in events { dayCounts[calendar.startOfDay(for: event.startDate), default: 0] += 1 }
        let start = calendar.dateInterval(of: .weekOfYear, for: date)!.start
        week = (0..<7).map { offset in
            let value = calendar.date(byAdding: .day, value: offset, to: start)!
            return Day(date: value, eventCount: dayCounts[calendar.startOfDay(for: value), default: 0],
                       today: calendar.isDate(value, inSameDayAs: date))
        }
        monthHighlights = Set(events.filter { calendar.isDate($0.startDate, equalTo: date, toGranularity: .month) }
            .map { calendar.component(.day, from: $0.startDate) })
        countdownDays = countdown.map { max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: $0.targetDate)).day ?? 0) } ?? 0
        countdownMonths = countdown.map { max(0, calendar.dateComponents([.month], from: date, to: $0.targetDate).month ?? 0) } ?? 0
        focusProgress = focus.map { min(1, max(0, 1 - $0.remaining(at: date) / Double($0.durationMinutes * 60))) } ?? 0
    }
}

extension WidgetType {
    var supportedSizes: [WidgetSize] {
        switch self {
        case .agenda: [.inline, .rectangular, .small, .medium, .large]
        case .month: [.inline, .circular, .rectangular, .small]
        case .week: [.rectangular, .medium]
        case .mini: [.small, .large]
        case .habit, .focus: [.circular, .rectangular, .small]
        case .countdown: [.inline, .circular, .rectangular, .small]
        case .ritual: [.circular, .rectangular, .small, .medium]
        }
    }
}

extension WidgetSize {
    var kitFamily: WidgetFamily {
        switch self {
        case .inline: .accessoryInline
        case .circular: .accessoryCircular
        case .rectangular: .accessoryRectangular
        case .small: .systemSmall
        case .medium: .systemMedium
        case .large: .systemLarge
        }
    }
}

private struct WidgetContextKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var haloWidgetContext: Bool {
        get { self[WidgetContextKey.self] }
        set { self[WidgetContextKey.self] = newValue }
    }
}
