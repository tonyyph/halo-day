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

enum TimeOfDay: String, Codable, CaseIterable, Sendable, Identifiable {
    case morning, afternoon, evening, anytime
    var id: String { rawValue }
    var title: String {
        switch self {
        case .morning: String(localized: "Morning")
        case .afternoon: String(localized: "Afternoon")
        case .evening: String(localized: "Evening")
        case .anytime: String(localized: "Anytime")
        }
    }
    /// Where this slot sits on the 24-hour Orbit.
    var anchorHour: Double {
        switch self {
        case .morning: 7.5
        case .afternoon: 13.5
        case .evening: 20
        case .anytime: 12
        }
    }
}

struct Habit: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var title: String
    var icon: String
    var accentColor: String
    var completedDates: [Date] = []
    var targetFrequency: Int = 1
    var timeOfDay: TimeOfDay = .anytime
    enum CodingKeys: String, CodingKey { case id, title, icon, accentColor, completedDates, targetFrequency, timeOfDay }
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

extension Habit {
    /// Tolerant decoding: habits saved before v2 have no `timeOfDay`.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        icon = try container.decode(String.self, forKey: .icon)
        accentColor = try container.decode(String.self, forKey: .accentColor)
        completedDates = try container.decodeIfPresent([Date].self, forKey: .completedDates) ?? []
        targetFrequency = try container.decodeIfPresent(Int.self, forKey: .targetFrequency) ?? 1
        timeOfDay = try container.decodeIfPresent(TimeOfDay.self, forKey: .timeOfDay) ?? .anytime
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
extension UserSettings {
    /// v1 themes map onto v2 skies until settings migrate in Phase 4.
    var skyID: SkyID {
        switch selectedThemeId {
        case "graphiteFocus", "midnightGold": .celestial
        case "champagneDay": .goldenHour
        case "ivoryMinimal": .instrument
        default: .livingSky
        }
    }
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
