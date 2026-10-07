import ActivityKit
import Foundation

@MainActor
protocol LiveActivityProviding {
    func start(focus: FocusSession, sky: SkyID) async throws
    func update(focus: FocusSession) async
    func end() async
}
@MainActor
final class LiveActivityService: LiveActivityProviding {
    var enabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }
    func start(focus: FocusSession, sky: SkyID) async throws {
        guard enabled else { throw LiveActivityError.disabled }
        await end()
        let attributes = HaloActivityAttributes(title: focus.title, startDate: focus.startDate, endDate: focus.endDate, themeId: sky.rawValue, accentColor: focus.accentColor)
        _ = try Activity.request(attributes: attributes, content: ActivityContent(state: .init(endDate: focus.endDate, phase: "running"), staleDate: focus.endDate), pushType: nil)
    }
    func eventCountdown(_ event: CalendarEvent, sky: SkyID) async throws {
        guard enabled else { throw LiveActivityError.disabled }
        guard event.startDate > .now, event.startDate.timeIntervalSinceNow <= 3600 else { throw LiveActivityError.tooEarly }
        await end()
        _ = try Activity.request(attributes: HaloActivityAttributes(title: event.title, startDate: .now, endDate: event.startDate, themeId: sky.rawValue, accentColor: event.accentColor, isEvent: true), content: ActivityContent(state: .init(endDate: event.startDate, phase: "countdown"), staleDate: event.startDate), pushType: nil)
    }
    func update(focus: FocusSession) async {
        for activity in Activity<HaloActivityAttributes>.activities where !activity.attributes.isEvent {
            await activity.update(ActivityContent(state: .init(endDate: focus.endDate, pausedRemaining: focus.pausedRemaining, phase: focus.isPaused ? "paused" : "running"), staleDate: focus.isPaused ? nil : focus.endDate))
        }
    }
    /// A natural finish: show "Done" for a while instead of vanishing.
    func finish() async {
        for activity in Activity<HaloActivityAttributes>.activities where !activity.attributes.isEvent {
            await activity.end(ActivityContent(state: .init(endDate: activity.content.state.endDate, phase: "finished"), staleDate: nil),
                               dismissalPolicy: .after(.now.addingTimeInterval(15 * 60)))
        }
    }
    func end() async {
        for activity in Activity<HaloActivityAttributes>.activities {
            await activity.end(ActivityContent(state: .init(endDate: .now, phase: "finished"), staleDate: nil), dismissalPolicy: .immediate)
        }
    }
    enum LiveActivityError: LocalizedError {
        case disabled, tooEarly
        var errorDescription: String? {
            switch self {
            case .disabled: String(localized: "Live Activities are turned off for Halo Day in iOS Settings.")
            case .tooEarly: String(localized: "Start a countdown in the hour before your event.")
            }
        }
    }
}
