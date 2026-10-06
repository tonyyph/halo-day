import Foundation

/// Everything a Lock Screen or Home Screen widget needs, computed the same way in Studio and in WidgetKit.
struct WidgetData: Sendable {
    struct MonthProgress: Sendable {
        var day: Int
        var daysInMonth: Int
        var daysLeft: Int { daysInMonth - day }
        var fraction: Double { Double(day) / Double(max(1, daysInMonth)) }
    }

    var date: Date
    var events: [CalendarEvent]
    var habits: [Habit]
    var focus: FocusSession?
    var countdown: Countdown?
    var isSample: Bool
    var calendar: Calendar = .current

    /// Today's timed events, in order.
    var timedToday: [CalendarEvent] {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return events.filter { !$0.isAllDay && $0.startDate < end && $0.endDate > start }
            .sorted { ($0.startDate, $0.endDate, $0.id) < ($1.startDate, $1.endDate, $1.id) }
    }
    /// The event happening now, else the next one today.
    var nextEvent: CalendarEvent? { timedToday.first { $0.endDate > date } }
    func upcoming(limit: Int) -> [CalendarEvent] { Array(timedToday.filter { $0.endDate > date }.prefix(limit)) }

    var monthProgress: MonthProgress {
        MonthProgress(day: calendar.component(.day, from: date), daysInMonth: calendar.range(of: .day, in: .month, for: date)?.count ?? 30)
    }
    var ritualsDone: Int { habits.filter { $0.isCompleted(on: date) }.count }
    var countdownDays: Int? {
        countdown.map { max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: $0.targetDate)).day ?? 0) }
    }
    var orbit: OrbitContent {
        let day = calendar.startOfDay(for: date)
        return OrbitContent(layout: OrbitLayout(day: day, events: timedToday, calendar: calendar, maxLanes: 1),
                            nowHour: OrbitGeometry.hours(of: date, calendar: calendar))
    }
}
