import Foundation

/// When a widget timeline needs a fresh entry: now, today's future event boundaries, a running focus's end,
/// optionally each hour (for sky backgrounds), and midnight.
enum WidgetTimeline {
    static func entryDates(now: Date, events: [CalendarEvent], focus: FocusSession?, hourly: Bool, calendar: Calendar = .current) -> [Date] {
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        var dates: Set<Date> = [now, midnight]
        for event in events where !event.isAllDay {
            for boundary in [event.startDate, event.endDate] where boundary > now && boundary < midnight { dates.insert(boundary) }
        }
        if let focus, focus.isActive, !focus.isPaused, focus.endDate > now, focus.endDate < midnight { dates.insert(focus.endDate) }
        // Five-minute steps in the 90 minutes before the next event keep "In 25 min" fresh.
        if let next = events.filter({ !$0.isAllDay && $0.startDate > now }).min(by: { $0.startDate < $1.startDate }) {
            for step in 1...18 {
                let tick = next.startDate.addingTimeInterval(Double(-step * 5 * 60))
                if tick > now && tick < midnight { dates.insert(tick) }
            }
        }
        if hourly, var hour = calendar.dateInterval(of: .hour, for: now)?.end {
            while hour < midnight { dates.insert(hour); hour.addTimeInterval(3600) }
        }
        return dates.sorted()
    }
}

/// Everything one widget entry draws, read from the App Group.
struct WidgetSnapshot: Sendable {
    var data: WidgetData
    var setup: LockSetup
    var isPremium: Bool
    var coordinate: GeoCoordinate

    static func load(storage: AppGroupStorage, date: Date, setupID: UUID?) -> WidgetSnapshot {
        let settings = storage.settings
        let snapshot = storage.snapshot
        let events = snapshot.isSample ? MockData.events(on: date) : snapshot.events
        let setups = storage.setups
        let active = storage.activeSetupID
        let setup = setups.first { $0.id == setupID } ?? setups.first { $0.id == active } ?? setups.first
            ?? .starter(name: String(localized: "My Halo"), sky: settings.skyID)
        return WidgetSnapshot(
            data: WidgetData(date: date, events: events, habits: storage.habits, focus: storage.focus,
                             countdown: storage.countdowns.filter { $0.targetDate >= Calendar.current.startOfDay(for: date) }.min { $0.targetDate < $1.targetDate },
                             isSample: snapshot.isSample),
            setup: setup, isPremium: settings.isPremium,
            coordinate: settings.approxCoordinate ?? TimeZoneLocator.approximateCoordinate(for: .current, at: date))
    }
}

extension WidgetKind {
    /// Where tapping the widget lands in the v2 app.
    func url(for data: WidgetData) -> URL {
        let path: String = switch self {
        case .orbit, .rhythm, .rituals: "day"
        case .nextUp: data.nextEvent.flatMap { $0.id.addingPercentEncoding(withAllowedCharacters: .alphanumerics) }.map { "event?id=\($0)" } ?? "day"
        case .countdown: "you"
        case .month: "calendar"
        }
        return URL(string: "haloday://\(path)")!
    }
}
