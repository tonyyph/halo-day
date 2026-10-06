import Foundation

enum ZoomLevel: Int, CaseIterable, Comparable, Sendable, Identifiable {
    case day, week, month
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .day: String(localized: "Day")
        case .week: String(localized: "Week")
        case .month: String(localized: "Month")
        }
    }
    var zoomedOut: ZoomLevel { ZoomLevel(rawValue: min(rawValue + 1, ZoomLevel.month.rawValue))! }
    var zoomedIn: ZoomLevel { ZoomLevel(rawValue: max(rawValue - 1, ZoomLevel.day.rawValue))! }
    static func < (lhs: ZoomLevel, rhs: ZoomLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// One day summarised for a mini-orbit in the week strip or month grid.
struct MiniDay: Identifiable, Hashable, Sendable {
    var day: Date
    var arcs: [OrbitArc]
    var eventCount: Int
    var busyHours: Double
    var ritualsDone: Int
    var ritualsTotal: Int
    var isToday: Bool
    var key: String
    var id: String { key }
    var allRitualsDone: Bool { ritualsTotal > 0 && ritualsDone == ritualsTotal }
}

enum ZoomBuilder {
    static func miniDay(_ day: Date, now: Date, events: [CalendarEvent], habits: [Habit], calendar: Calendar) -> MiniDay {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let onDay = events.filter { $0.startDate < end && $0.endDate > start }
        let timed = onDay.filter { !$0.isAllDay }
        let components = calendar.dateComponents([.year, .month, .day], from: start)
        return MiniDay(day: start, arcs: OrbitLayout(day: start, events: timed, calendar: calendar).arcs,
                       eventCount: onDay.count, busyHours: busyHours(timed, dayStart: start, calendar: calendar),
                       ritualsDone: habits.filter { $0.isCompleted(on: start) }.count, ritualsTotal: habits.count,
                       isToday: calendar.isDate(now, inSameDayAs: start),
                       key: String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0))
    }

    static func week(containing date: Date, now: Date, events: [CalendarEvent], habits: [Habit], calendar: Calendar) -> [MiniDay] {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)!.start
        return (0..<7).map { miniDay(calendar.date(byAdding: .day, value: $0, to: start)!, now: now, events: events, habits: habits, calendar: calendar) }
    }

    /// Rows of seven, padded with nil before the 1st and after the last day, starting on the calendar's first weekday.
    static func month(containing date: Date, now: Date, events: [CalendarEvent], habits: [Habit], calendar: Calendar) -> [[MiniDay?]] {
        let first = calendar.dateInterval(of: .month, for: date)!.start
        let count = calendar.range(of: .day, in: .month, for: first)!.count
        let lead = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        var cells: [MiniDay?] = Array(repeating: nil, count: lead)
        cells += (0..<count).map { miniDay(calendar.date(byAdding: .day, value: $0, to: first)!, now: now, events: events, habits: habits, calendar: calendar) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<($0 + 7)]) }
    }

    /// Hours covered by timed events within the day, with overlaps merged.
    static func busyHours(_ events: [CalendarEvent], dayStart: Date, calendar: Calendar) -> Double {
        let spans = events.filter { !$0.isAllDay }
            .map { (max(0, OrbitGeometry.wallHours(of: $0.startDate, relativeTo: dayStart, calendar: calendar)),
                    min(24, OrbitGeometry.wallHours(of: $0.endDate, relativeTo: dayStart, calendar: calendar))) }
            .filter { $0.1 > $0.0 }
            .sorted { $0.0 < $1.0 }
        var total = 0.0
        var current: (Double, Double)?
        for span in spans {
            if let open = current, span.0 <= open.1 {
                current = (open.0, max(open.1, span.1))
            } else {
                if let open = current { total += open.1 - open.0 }
                current = span
            }
        }
        if let open = current { total += open.1 - open.0 }
        return total
    }
}
