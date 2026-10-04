import EventKit
import Foundation
import UIKit

@MainActor
protocol CalendarProviding {
    var isAuthorized: Bool { get }
    func requestAccess() async throws -> Bool
    func events(in interval: DateInterval, calendarIDs: [String]) -> [CalendarEvent]
}
@MainActor
final class CalendarService: CalendarProviding {
    let store = EKEventStore()
    var isAuthorized: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }
    func requestAccess() async throws -> Bool { try await store.requestFullAccessToEvents() }
    func events(in interval: DateInterval, calendarIDs: [String] = []) -> [CalendarEvent] {
        guard isAuthorized else {
            var day = interval.start
            var result: [CalendarEvent] = []
            while day < interval.end {
                result += MockData.events(on: day)
                day = Calendar.current.date(byAdding: .day, value: 1, to: day)!
            }
            return result
        }
        let calendars = store.calendars(for: .event).filter { calendarIDs.isEmpty || calendarIDs.contains($0.calendarIdentifier) }
        if !calendarIDs.isEmpty && calendars.isEmpty { return [] }
        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: calendars)
        return store.events(matching: predicate).map { event in
            CalendarEvent(id: "\(event.eventIdentifier ?? UUID().uuidString)-\(event.startDate.timeIntervalSince1970)", title: event.title ?? String(localized: "Untitled event"), startDate: event.startDate, endDate: event.endDate, location: event.location, calendarName: event.calendar.title, accentColor: colorHex(event.calendar.cgColor), isAllDay: event.isAllDay)
        }.sorted { $0.startDate < $1.startDate }
    }
    func today() -> [CalendarEvent] { events(in: Calendar.current.dateInterval(of: .day, for: .now)!) }
    func week() -> [CalendarEvent] { events(in: Calendar.current.dateInterval(of: .weekOfYear, for: .now)!) }
    func month() -> [CalendarEvent] { events(in: Calendar.current.dateInterval(of: .month, for: .now)!) }
    private func colorHex(_ color: CGColor?) -> String {
        guard let color else { return ThemeRegistry.all[1].accentColor }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(cgColor: color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }
}
