import Foundation

/// How the agenda is drawn into a Lock Screen wallpaper.
enum AgendaLayout: String, Codable, CaseIterable, Sendable, Identifiable {
    case week, month, orbit
    var id: String { rawValue }
    var title: String {
        switch self {
        case .week: String(localized: "Week")
        case .month: String(localized: "Month")
        case .orbit: String(localized: "Orbit")
        }
    }
}

/// An agenda wallpaper: the calendar drawn into the wallpaper image itself, below iOS's clock.
/// iOS Lock Screen widgets cannot be this large or this colourful, so the picture carries it.
struct AgendaWallpaper: Codable, Hashable, Sendable {
    static let accents = ["8E1B23", "1F3A8A", "2E6B4F", "6B3FA0", "B4562A", "1C1C1E"]
    var layout: AgendaLayout = .month
    var accentHex = AgendaWallpaper.accents[0]
    /// The person's own photo behind the agenda instead of the sky.
    var usesPhoto = false
    /// Measured when the photo is chosen, so text over it takes the right ink.
    var photoIsDark = false
    /// Starts the agenda lower, under a row of Lock Screen widgets.
    var roomForWidgets = false

    init() {}
    private enum CodingKeys: String, CodingKey { case layout, accentHex, usesPhoto, photoIsDark, roomForWidgets }
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        layout = (try? c.decodeIfPresent(AgendaLayout.self, forKey: .layout)) ?? .month
        accentHex = (try? c.decodeIfPresent(String.self, forKey: .accentHex)) ?? Self.accents[0]
        usesPhoto = (try? c.decodeIfPresent(Bool.self, forKey: .usesPhoto)) ?? false
        photoIsDark = (try? c.decodeIfPresent(Bool.self, forKey: .photoIsDark)) ?? false
        roomForWidgets = (try? c.decodeIfPresent(Bool.self, forKey: .roomForWidgets)) ?? false
    }
}

struct AgendaDay: Hashable, Sendable, Identifiable {
    var date: Date
    var weekday: String
    var dayNumber: Int
    var isToday: Bool
    var items: [CalendarEvent]
    var more: Int
    var id: Date { date }
}

struct AgendaMonthCell: Hashable, Sendable {
    enum State: Hashable, Sendable { case outside, past, today, future }
    var state: State
    var hasEvents: Bool
}

/// Everything an agenda wallpaper shows, computed from a day-by-day event lookup.
struct AgendaData: Sendable {
    var now: Date
    var week: [AgendaDay]
    var upcoming: [CalendarEvent]
    var monthTitle: String
    var monthShort: String
    var dayOfMonth: Int
    var daysInMonth: Int
    /// Columns are weeks, each with seven cells in the calendar's weekday order.
    var monthColumns: [[AgendaMonthCell]]
    var weekdayInitials: [String]
    var isSample: Bool

    var monthFraction: Double { Double(dayOfMonth) / Double(max(1, daysInMonth)) }
    var daysLeft: Int { daysInMonth - dayOfMonth }
}

enum AgendaBuilder {
    static let chipsPerDay = 4

    static func build(now: Date, calendar: Calendar = .current, isSample: Bool, events: (Date) -> [CalendarEvent]) -> AgendaData {
        let today = calendar.startOfDay(for: now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        let weekdayFormat = Date.FormatStyle.dateTime.weekday(.abbreviated).locale(calendar.locale ?? .current)
        let week = (0..<7).map { offset -> AgendaDay in
            let date = calendar.date(byAdding: .day, value: offset, to: weekStart)!
            let all = sorted(events(date))
            return AgendaDay(date: date, weekday: date.formatted(weekdayFormat), dayNumber: calendar.component(.day, from: date),
                             isToday: calendar.isDate(date, inSameDayAs: today),
                             items: Array(all.prefix(chipsPerDay)), more: max(0, all.count - chipsPerDay))
        }
        let upcoming = sorted(events(today)).filter { !$0.isAllDay && $0.endDate > now }

        let month = calendar.dateInterval(of: .month, for: now)!
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)!.count
        let firstColumn = calendar.dateInterval(of: .weekOfYear, for: month.start)!.start
        var columns: [[AgendaMonthCell]] = []
        var cursor = firstColumn
        while cursor < month.end {
            var column: [AgendaMonthCell] = []
            for _ in 0..<7 {
                let state: AgendaMonthCell.State
                if !month.contains(cursor) { state = .outside }
                else if calendar.isDate(cursor, inSameDayAs: today) { state = .today }
                else { state = cursor < today ? .past : .future }
                column.append(AgendaMonthCell(state: state, hasEvents: state != .outside && !events(cursor).isEmpty))
                cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
            }
            columns.append(column)
        }
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        let initials = Array(symbols[first...] + symbols[..<first])
        let locale = calendar.locale ?? .current
        return AgendaData(now: now, week: week, upcoming: upcoming,
                          monthTitle: now.formatted(.dateTime.month(.wide).locale(locale)),
                          monthShort: now.formatted(.dateTime.month(.abbreviated).locale(locale)),
                          dayOfMonth: calendar.component(.day, from: now), daysInMonth: daysInMonth,
                          monthColumns: columns, weekdayInitials: initials, isSample: isSample)
    }

    /// All-day first, then by start time.
    private static func sorted(_ events: [CalendarEvent]) -> [CalendarEvent] {
        events.sorted { ($0.isAllDay ? 0 : 1, $0.startDate, $0.title) < ($1.isAllDay ? 0 : 1, $1.startDate, $1.title) }
    }
}
