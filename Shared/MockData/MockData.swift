import Foundation

enum MockData {
    static func events(on date: Date = .now) -> [CalendarEvent] {
        let day = Calendar.current.startOfDay(for: date)
        let items: [(String, Int, Int, String, String?)] = [
            ("Standup", 9, 30, "Work", nil), ("Design review", 10, 45, "Work", "Studio B"),
            ("Lunch with Mai", 13, 60, "Personal", "The little café"), ("Pilates", 16, 50, "Health", nil), ("Dinner", 19, 90, "Personal", nil)
        ]
        return items.enumerated().map { index, item in
            let start = Calendar.current.date(byAdding: .minute, value: item.1 * 60 + (index == 1 ? 30 : 0), to: day)!
            return CalendarEvent(id: "sample-\(day.timeIntervalSince1970)-\(index)", title: String(localized: String.LocalizationValue(item.0)), startDate: start, endDate: start.addingTimeInterval(Double(item.2 * 60)), location: item.4.map { String(localized: String.LocalizationValue($0)) }, calendarName: String(localized: String.LocalizationValue(item.3)), accentColor: calendarColors[item.3] ?? "5B74D6", source: "sample")
        }
    }
    /// Sample calendars get distinct colours, like real calendars do.
    private static let calendarColors = ["Work": "5B74D6", "Personal": "E2607D", "Health": "4FAE86"]
    static let habits: [Habit] = [
        Habit(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, title: String(localized: "Drink water"), icon: "drop", accentColor: ThemeRegistry.all[0].light.accent, timeOfDay: .morning),
        Habit(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, title: String(localized: "A page of journaling"), icon: "book.closed", accentColor: ThemeRegistry.all[1].light.accent, timeOfDay: .evening),
        Habit(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, title: String(localized: "A little movement"), icon: "figure.walk", accentColor: ThemeRegistry.all[4].light.accent, timeOfDay: .afternoon)
    ]
}
