import SwiftUI
import Observation
import WidgetKit
import EventKit

@MainActor @Observable
final class HaloModel {
    var settings: UserSettings
    var habits: [Habit]
    var presets: [WidgetPreset]
    var events: [CalendarEvent] = []
    var focus: FocusSession?
    var focusHistory: [FocusSession]
    var countdowns: [Countdown]
    var selectedDate = Date.now
    var tab = 0
    var showPaywall = false
    var showSettings = false
    var showGuide = false
    var error: String?
    var selectedEvent: CalendarEvent?
    var purchases = PurchaseService()
    private let storage = AppGroupStorage.shared
    let calendarService = CalendarService()
    let notifications = NotificationService()
    let activities = LiveActivityService()
    var theme: HaloTheme { ThemeRegistry.theme(settings.selectedThemeId) }
    var isSample: Bool { !settings.calendarPermissionGranted }
    var todayEvents: [CalendarEvent] { events(on: .now) }
    var nextEvent: CalendarEvent? { nextEvent(at: .now) }
    var completedHabits: Int { completedHabits(on: .now) }
    var progress: Double { progress(at: .now) }
    func nextEvent(at date: Date) -> CalendarEvent? { events(on: date).first { $0.endDate > date } }
    func completedHabits(on date: Date) -> Int { habits.filter { $0.isCompleted(on: date) }.count }
    func progress(at date: Date) -> Double {
        let hour = Double(Calendar.current.component(.hour, from: date)) + Double(Calendar.current.component(.minute, from: date)) / 60
        let elapsed = min(1, max(0, (hour - Double(settings.dayStartHour)) / Double(max(1, settings.dayEndHour - settings.dayStartHour))))
        return habits.isEmpty ? elapsed : elapsed * 0.5 + Double(completedHabits(on: date)) / Double(habits.count) * 0.5
    }
    init() {
        let storage = AppGroupStorage.shared
        settings = storage.settings; habits = storage.habits; presets = storage.presets; focus = storage.focus
        focusHistory = storage.read("focusHistory", fallback: [])
        countdowns = storage.countdowns
    }
    func persist() {
        settings.isPremium = purchases.isPremium
        do { try storage.write(settings, key: "settings") }
        catch { self.error = error.localizedDescription }
        WidgetCenter.shared.reloadAllTimelines()
    }
    func saveSettings() { persist(); Task { await refresh() } }
    func refresh() async {
        settings = storage.settings; habits = storage.habits; focus = storage.focus
        settings.calendarPermissionGranted = calendarService.isAuthorized
        settings.notificationPermissionGranted = await notifications.isAuthorized()
        let month = Calendar.current.dateInterval(of: .month, for: selectedDate)!
        let current = Calendar.current.dateInterval(of: .month, for: .now)!
        let interval = DateInterval(start: min(month.start, current.start), end: max(month.end, current.end).addingTimeInterval(7 * 86400))
        events = calendarService.events(in: interval, calendarIDs: settings.enabledCalendarIDs)
        if !settings.includeAllDay { events.removeAll { $0.isAllDay } }
        do {
            try storage.write(CalendarSnapshot(events: events, isSample: isSample), key: "calendar")
            try storage.write(settings, key: "settings")
            try await notifications.plan(events: events, focus: focus, minutes: settings.eventReminderMinutes)
        } catch { self.error = error.localizedDescription }
        if let focus, focus.isActive, !focus.isPaused, focus.endDate <= .now { await stopFocus(completed: true) }
        WidgetCenter.shared.reloadAllTimelines()
    }
    func events(on date: Date) -> [CalendarEvent] {
        let interval = Calendar.current.dateInterval(of: .day, for: date)!
        return events.filter { $0.startDate < interval.end && $0.endDate > interval.start }
    }
    func requestCalendar() async {
        do { settings.calendarPermissionGranted = try await calendarService.requestAccess(); persist(); await refresh() }
        catch { self.error = error.localizedDescription }
    }
    func requestNotifications() async {
        do { settings.notificationPermissionGranted = try await notifications.requestAccess(); persist(); await refresh() }
        catch { self.error = error.localizedDescription }
    }
    func applyTheme(_ theme: HaloTheme) {
        guard !theme.isPremium || purchases.isPremium else { showPaywall = true; return }
        settings.selectedThemeId = theme.id; persist()
    }
    func savePreset(_ preset: WidgetPreset) -> Bool {
        guard purchases.isPremium || (!ThemeRegistry.theme(preset.themeId).isPremium && !preset.widgetType.premium && ![.medium, .large].contains(preset.widgetFamily) && presets.count < 1) else { showPaywall = true; return false }
        presets.append(preset)
        do { try storage.write(presets, key: "presets"); try storage.write(preset.id.uuidString, key: "activePreset"); WidgetCenter.shared.reloadAllTimelines(); return true }
        catch { self.error = error.localizedDescription; return false }
    }
    func activatePreset(_ preset: WidgetPreset) {
        do { try storage.write(preset.id.uuidString, key: "activePreset"); WidgetCenter.shared.reloadAllTimelines() }
        catch { self.error = error.localizedDescription }
    }
    func removePreset(_ id: UUID) {
        presets.removeAll { $0.id == id }
        do { try storage.write(presets, key: "presets"); WidgetCenter.shared.reloadAllTimelines() } catch { self.error = error.localizedDescription }
    }
    func toggleHabit(_ habit: Habit) {
        do { try storage.toggleHabit(habit.id); habits = storage.habits }
        catch { self.error = error.localizedDescription }
    }
    func saveHabit(_ habit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) { habits[index] = habit }
        else {
            guard purchases.isPremium || habits.count < 3 else { showPaywall = true; return }
            habits.append(habit)
        }
        do { try storage.write(habits, key: "habits"); WidgetCenter.shared.reloadAllTimelines() } catch { self.error = error.localizedDescription }
    }
    func removeHabit(_ id: UUID) {
        habits.removeAll { $0.id == id }
        do { try storage.write(habits, key: "habits"); WidgetCenter.shared.reloadAllTimelines() } catch { self.error = error.localizedDescription }
    }
    func saveCountdown(_ countdown: Countdown) {
        guard purchases.isPremium || countdowns.isEmpty else { showPaywall = true; return }
        countdowns.append(countdown)
        do { try storage.write(countdowns, key: "countdowns"); WidgetCenter.shared.reloadAllTimelines() } catch { self.error = error.localizedDescription }
    }
    func startFocus(title: String, minutes: Int) async {
        await activities.end()
        let session = FocusSession(title: title.isEmpty ? String(localized: "Deep work") : title, startDate: .now, endDate: .now.addingTimeInterval(Double(minutes * 60)), durationMinutes: minutes, accentColor: theme.dark.accent)
        focus = session
        do {
            try storage.write(session, key: "focus")
            try await notifications.plan(events: events, focus: session, minutes: settings.eventReminderMinutes)
            if purchases.isPremium && settings.liveActivities { try await activities.start(focus: session, theme: theme) }
        } catch { self.error = error.localizedDescription }
        WidgetCenter.shared.reloadAllTimelines()
    }
    func pauseFocus() async {
        guard var session = focus, session.isActive else { return }
        if let remaining = session.pausedRemaining { session.endDate = .now.addingTimeInterval(remaining); session.pausedRemaining = nil }
        else { session.pausedRemaining = session.remaining() }
        focus = session
        do { try storage.write(session, key: "focus"); try await notifications.plan(events: events, focus: session, minutes: settings.eventReminderMinutes) } catch { self.error = error.localizedDescription }
        await activities.update(focus: session); WidgetCenter.shared.reloadAllTimelines()
    }
    func stopFocus(completed: Bool = false) async {
        if var session = storage.focus, session.isActive {
            session.isActive = false
            if !completed { session.endDate = .now }
            focus = session; focusHistory.insert(session, at: 0)
            do { try storage.write(session, key: "focus"); try storage.write(focusHistory, key: "focusHistory") } catch { self.error = error.localizedDescription }
        }
        await activities.end()
        do { try await notifications.plan(events: events, focus: nil, minutes: settings.eventReminderMinutes) } catch { self.error = error.localizedDescription }
        WidgetCenter.shared.reloadAllTimelines()
    }
    func countDown(_ event: CalendarEvent) async {
        guard purchases.isPremium else { showPaywall = true; return }
        if focus?.isActive == true { await stopFocus() }
        do { try await activities.eventCountdown(event, theme: theme) } catch { self.error = error.localizedDescription }
    }
    func route(_ url: URL) {
        switch url.host {
        case "calendar":
            tab = 1
            if let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "date" })?.value {
                let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
                if let date = formatter.date(from: value) { selectedDate = date }
            }
        case "studio": tab = 2
        case "rituals": tab = 3
        case "focus": tab = 4
        case "paywall": showPaywall = true
        case "event": tab = 0; selectedEvent = events.first { $0.id == url.lastPathComponent }
        default: tab = 0
        }
    }
}
