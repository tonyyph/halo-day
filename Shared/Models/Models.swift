import Foundation
import ActivityKit

struct CalendarEvent: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var location: String?
    var calendarName: String
    var accentColor: String
    var isAllDay: Bool = false
    var source: String = "calendar"
}

struct Habit: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var title: String
    var icon: String
    var accentColor: String
    var completedDates: [Date] = []
    var targetFrequency: Int = 1
    func isCompleted(on date: Date = .now) -> Bool {
        completedDates.contains { Calendar.current.isDate($0, inSameDayAs: date) }
    }
    var streakCount: Int { streak(asOf: .now) }
    func streak(asOf date: Date) -> Int {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: date)
        if !isCompleted(on: day) { day = calendar.date(byAdding: .day, value: -1, to: day)! }
        var result = 0
        while isCompleted(on: day) {
            result += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return result
    }
    mutating func toggle(on date: Date = .now) {
        if isCompleted(on: date) {
            completedDates.removeAll { Calendar.current.isDate($0, inSameDayAs: date) }
        } else { completedDates.append(Calendar.current.startOfDay(for: date)) }
    }
}

enum WidgetType: String, CaseIterable, Codable, Sendable, Identifiable {
    case agenda, month, week, mini, habit, focus, countdown, ritual
    var id: String { rawValue }
    var title: String {
        switch self {
        case .agenda: "Today Agenda"
        case .month: "Month Progress"
        case .week: "Week Strip"
        case .mini: "Mini Calendar"
        case .habit: "Habit Streak"
        case .focus: "Focus Session"
        case .countdown: "Countdown"
        case .ritual: "Daily Ritual"
        }
    }
    var premium: Bool { self == .habit || self == .focus }
}
enum WidgetSize: String, CaseIterable, Codable, Sendable, Identifiable {
    case inline, circular, rectangular, small, medium, large
    var id: String { rawValue }
    var isAccessory: Bool { [.inline, .circular, .rectangular].contains(self) }
}
struct WidgetPreset: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var name: String
    var widgetType: WidgetType = .agenda
    var widgetFamily: WidgetSize = .rectangular
    var themeId: String = "pearlHalo"
    var dataSource: String = "calendar"
    var density: Int = 2
    var createdAt: Date = .now
    var updatedAt: Date = .now
}
struct FocusSession: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var title: String
    var startDate: Date
    var endDate: Date
    var durationMinutes: Int
    var accentColor: String
    var isActive: Bool = true
    var pausedRemaining: TimeInterval?
    var isPaused: Bool { pausedRemaining != nil }
    func remaining(at date: Date = .now) -> TimeInterval { max(0, pausedRemaining ?? endDate.timeIntervalSince(date)) }
}
struct Countdown: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var title: String
    var targetDate: Date
}
struct UserSettings: Codable, Sendable {
    var selectedThemeId = "pearlHalo"
    var hasCompletedOnboarding = false
    var calendarPermissionGranted = false
    var notificationPermissionGranted = false
    var isPremium = false
    var firstName = ""
    var haptics = true
    var dayStartHour = 7
    var dayEndHour = 22
    var eventReminderMinutes = 10
    var enabledCalendarIDs: [String] = []
    var includeAllDay = true
    var liveActivities = true
}
struct CalendarSnapshot: Codable, Sendable {
    var generatedAt: Date = .now
    var events: [CalendarEvent] = []
    var isSample = true
}
struct HaloActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endDate: Date
        var pausedRemaining: TimeInterval?
        var phase: String = "running"
    }
    var title: String
    var startDate: Date
    var endDate: Date
    var themeId: String
    var accentColor: String
    var isEvent: Bool = false
}
