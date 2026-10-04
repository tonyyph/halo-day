import UserNotifications
import Foundation

@MainActor
final class NotificationService {
    private let center = UNUserNotificationCenter.current()
    func requestAccess() async throws -> Bool { try await center.requestAuthorization(options: [.alert, .sound, .badge]) }
    func isAuthorized() async -> Bool {
        let status = await center.notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }
    func plan(events: [CalendarEvent], focus: FocusSession?, minutes: Int) async throws {
        let old = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: old.filter { $0.identifier.hasPrefix("halo.") }.map(\.identifier))
        guard await isAuthorized() else { return }
        var items: [(String, String, Date)] = []
        if let focus, focus.isActive, !focus.isPaused, focus.endDate > .now { items.append(("halo.focus", String(localized: "Beautifully done. Your focus session is complete."), focus.endDate)) }
        if minutes > 0 {
            items += events.filter { !$0.isAllDay && $0.source != "sample" }.compactMap { event in
                let trigger = event.startDate.addingTimeInterval(Double(-minutes * 60))
                return trigger > .now ? ("halo.event.\(event.id)", event.title, trigger) : nil
            }.sorted { $0.2 < $1.2 }
        }
        for item in items.prefix(64) {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Halo Day"); content.body = item.1; content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, item.2.timeIntervalSinceNow), repeats: false)
            try await center.add(UNNotificationRequest(identifier: item.0, content: content, trigger: trigger))
        }
    }
}
