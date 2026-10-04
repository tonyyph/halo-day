import AppIntents
import Foundation
import ActivityKit
import WidgetKit
import UserNotifications

struct ToggleRitualIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete ritual"
    @Parameter(title: "Ritual ID") var ritualID: String
    init() {}
    init(ritualID: String) { self.ritualID = ritualID }
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: ritualID) { try AppGroupStorage.shared.toggleHabit(id) }
        return .result()
    }
}
struct PauseFocusIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause or resume focus"
    func perform() async throws -> some IntentResult {
        let storage = AppGroupStorage.shared
        guard var focus = storage.focus, focus.isActive else { return .result() }
        if let remaining = focus.pausedRemaining {
            focus.endDate = Date.now.addingTimeInterval(remaining); focus.pausedRemaining = nil
        } else { focus.pausedRemaining = focus.remaining() }
        try storage.write(focus, key: "focus")
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["halo.focus"])
        if !focus.isPaused && focus.endDate > .now {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Halo Day")
            content.body = String(localized: "Beautifully done. Your focus session is complete.")
            content.sound = .default
            try await center.add(UNNotificationRequest(identifier: "halo.focus", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, focus.endDate.timeIntervalSinceNow), repeats: false)))
        }
        for activity in Activity<HaloActivityAttributes>.activities where !activity.attributes.isEvent {
            await activity.update(ActivityContent(state: .init(endDate: focus.endDate, pausedRemaining: focus.pausedRemaining, phase: focus.isPaused ? "paused" : "running"), staleDate: focus.isPaused ? nil : focus.endDate))
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
struct EndFocusIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "End focus"
    func perform() async throws -> some IntentResult {
        let storage = AppGroupStorage.shared
        if var focus = storage.focus { focus.isActive = false; try storage.write(focus, key: "focus") }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["halo.focus"])
        for activity in Activity<HaloActivityAttributes>.activities {
            await activity.end(ActivityContent(state: .init(endDate: .now, phase: "finished"), staleDate: nil), dismissalPolicy: .immediate)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
