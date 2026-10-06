import SwiftUI
import Observation
import WidgetKit
import EventKit

enum AppTab: Hashable { case day, studio, you }

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
    var tab: AppTab = .day
    var showPaywall = false
    var showSettings = false
    var showGuide = false
    var error: String?
    var showFocus = false
    /// A session that just finished while the app was open; the focus cover shows its bloom.
    var completedFocus: FocusSession?
    /// The day the Day tab shows; nil follows today.
    var viewedDay: Date?
    /// Orbit Zoom level on the Day tab.
    var dayZoom: ZoomLevel = .day
    private var focusTimer: Task<Void, Never>?
    var skyCoordinate: GeoCoordinate { TimeZoneLocator.approximateCoordinate(for: .current) }
    /// The active session (if any) followed by history, newest first.
    var focusSessions: [FocusSession] { (focus.map { $0.isActive ? [$0] : [] } ?? []) + focusHistory }
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
        await completeFocusIfDue()
        scheduleFocusCompletion()
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
        scheduleFocusCompletion()
        WidgetCenter.shared.reloadAllTimelines()
    }
    func pauseFocus() async {
        guard var session = focus, session.isActive else { return }
        if let remaining = session.pausedRemaining { session.endDate = .now.addingTimeInterval(remaining); session.pausedRemaining = nil }
        else { session.pausedRemaining = session.remaining() }
        focus = session
        do { try storage.write(session, key: "focus"); try await notifications.plan(events: events, focus: session, minutes: settings.eventReminderMinutes) } catch { self.error = error.localizedDescription }
        scheduleFocusCompletion()
        await activities.update(focus: session); WidgetCenter.shared.reloadAllTimelines()
    }
    /// Completes a running session whose time is up. One that ended over a minute ago (the app was closed) completes quietly.
    func completeFocusIfDue(now: Date = .now) async {
        guard let session = focus, session.isActive, !session.isPaused, session.endDate <= now else { return }
        await stopFocus(completed: true)
        if now.timeIntervalSince(session.endDate) < 60, let finished = focus, !finished.isActive {
            completedFocus = finished
            showFocus = true
        }
    }
    /// Opens the focus cover at launch for a session that is still running or paused.
    func presentRunningFocus(now: Date = .now) {
        guard let session = focus, session.isActive, session.isPaused || session.endDate > now else { return }
        showFocus = true
    }
    /// The end-of-session timer lives here, not in a view, so minimizing the cover cannot cancel it.
    func scheduleFocusCompletion() {
        focusTimer?.cancel()
        guard let session = focus, session.isActive, !session.isPaused else { return }
        focusTimer = Task { [weak self] in
            let remaining = session.endDate.timeIntervalSinceNow
            if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
            guard !Task.isCancelled else { return }
            await self?.completeFocusIfDue()
        }
    }
    func stopFocus(completed: Bool = false) async {
        focusTimer?.cancel()
        if var session = focus, session.isActive {
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
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        switch url.host {
        case "calendar", "day":
            let date = query?.first(where: { $0.name == "date" })?.value.flatMap { value -> Date? in
                let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
                return formatter.date(from: value)
            }
            tab = .day
            dayZoom = url.host == "calendar" ? .month : .day
            if url.host == "day" || date != nil { viewedDay = date }
            if let date { selectedDate = date }
        case "studio": tab = .studio
        case "rituals", "you": tab = .you
        case "focus": tab = .day; showFocus = true
        case "paywall": showPaywall = true
        case "event": tab = .day; selectedEvent = events.first { $0.id == url.lastPathComponent }
        default: tab = .day; dayZoom = .day; viewedDay = nil
        }
    }
}
