import Foundation

/// The week at a glance for the You tab: seven mini-orbits, focus per day, ritual rate, the busiest hour and one sentence.
struct WeekRecap: Sendable {
    var days: [MiniDay]
    var focusMinutesByDay: [Int]
    var focusMinutes: Int
    var ritualRate: Double?
    var busiestHour: Int?
    var sentence: String
}

enum WeekRecapBuilder {
    static func build(containing date: Date, now: Date, events: [CalendarEvent], habits: [Habit], focusSessions: [FocusSession], calendar: Calendar) -> WeekRecap {
        let days = ZoomBuilder.week(containing: date, now: now, events: events, habits: habits, calendar: calendar)
        let finished = focusSessions.filter { !$0.isActive }
        let byDay = days.map { mini in
            finished.filter { calendar.isDate($0.startDate, inSameDayAs: mini.day) }
                .reduce(0) { $0 + max(0, Int($1.endDate.timeIntervalSince($1.startDate) / 60)) }
        }
        let today = calendar.startOfDay(for: now)
        let elapsed = days.filter { $0.day <= today }
        let possible = elapsed.count * habits.count
        let rate = possible > 0 ? Double(elapsed.reduce(0) { $0 + $1.ritualsDone }) / Double(possible) : nil
        var hours = [Double](repeating: 0, count: 24)
        for mini in days {
            for event in events where !event.isAllDay && event.startDate < calendar.date(byAdding: .day, value: 1, to: mini.day)! && event.endDate > mini.day {
                let start = max(0, OrbitGeometry.wallHours(of: event.startDate, relativeTo: mini.day, calendar: calendar))
                let end = min(24, OrbitGeometry.wallHours(of: event.endDate, relativeTo: mini.day, calendar: calendar))
                guard end > start else { continue }
                for hour in Int(start.rounded(.down))..<Int(end.rounded(.up)) where hour < 24 {
                    hours[hour] += min(end, Double(hour + 1)) - max(start, Double(hour))
                }
            }
        }
        let busiest = hours.indices.max { hours[$0] < hours[$1] }.flatMap { hours[$0] > 0 ? $0 : nil }
        let focus = byDay.reduce(0, +)
        return WeekRecap(days: days, focusMinutesByDay: byDay, focusMinutes: focus, ritualRate: rate, busiestHour: busiest,
                         sentence: sentence(focusMinutes: focus, ritualRate: rate, eventCount: days.reduce(0) { $0 + $1.eventCount }))
    }

    static func sentence(focusMinutes: Int, ritualRate: Double?, eventCount: Int) -> String {
        let rituals = ritualRate ?? 0
        if rituals >= 0.8 && focusMinutes >= 120 { return String(localized: "A steady week: rituals kept and real focus.") }
        if focusMinutes >= 300 { return String(localized: "A deep week — over \(focusMinutes / 60) hours of focus.") }
        if rituals >= 0.8 { return String(localized: "You kept almost every ritual this week.") }
        if eventCount >= 20 { return String(localized: "A full week. Leave a little room for yourself.") }
        return String(localized: "A gentle week. One small ritual is enough to begin.")
    }
}

enum RitualHistoryBuilder {
    /// `weeks` columns (oldest first) of seven days from the calendar's first weekday; nil marks days after `today`.
    static func grid(for habit: Habit, endingOn today: Date, weeks: Int = 12, calendar: Calendar = .current) -> [[Bool?]] {
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today)!.start
        let first = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisWeek)!
        let end = calendar.startOfDay(for: today)
        return (0..<weeks).map { week in
            (0..<7).map { offset in
                let day = calendar.date(byAdding: .day, value: week * 7 + offset, to: first)!
                return day > end ? nil : habit.isCompleted(on: day)
            }
        }
    }
}
