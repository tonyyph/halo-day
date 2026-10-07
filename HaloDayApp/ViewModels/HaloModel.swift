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
    /// v2 Lock Screen setups (replace presets).
    var setups: [LockSetup]
    var activeSetupID: UUID?
    var events: [CalendarEvent] = []
    var focus: FocusSession?
    var focusHistory: [FocusSession]
    var countdowns: [Countdown]
    var selectedDate = Date.now
    var tab: AppTab = .day
    /// Opening the paywall starts with no leftover purchase outcome from an earlier visit.
    var showPaywall = false { didSet { if showPaywall && !oldValue { purchases.message = nil } } }
    var showSettings = false
    var showGuide = false
    var error: String?
    var showFocus = false
    /// True while the opening splash plays; covers wait for it. Fixture mode has no splash.
    var isSplashing = true
    /// A session that just finished while the app was open; the focus cover shows its bloom.
    var completedFocus: FocusSession?
    /// The day the Day tab shows; nil follows today.
    var viewedDay: Date?
    /// Orbit Zoom level on the Day tab.
    var dayZoom: ZoomLevel = .day
    private var focusTimer: Task<Void, Never>?
    var skyCoordinate: GeoCoordinate { settings.approxCoordinate ?? TimeZoneLocator.approximateCoordinate(for: .current) }
    var location: any LocationProviding = LocationService()
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
        setups = storage.setups; activeSetupID = storage.activeSetupID
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
        focusHistory = storage.read("focusHistory", fallback: [])
        settings.calendarPermissionGranted = calendarService.isAuthorized
        settings.notificationPermissionGranted = await notifications.isAuthorized()
        let interval = Self.loadInterval(selected: selectedDate, now: .now)
        events = calendarService.events(in: interval, calendarIDs: settings.enabledCalendarIDs)
        if !settings.includeAllDay { events.removeAll { $0.isAllDay } }
        do {
            try storage.write(CalendarSnapshot(events: events, isSample: isSample), key: "calendar")
            try storage.write(settings, key: "settings")
            try await notifications.plan(events: events, focus: focus, minutes: settings.eventReminderMinutes)
        } catch { self.error = error.localizedDescription }
        await completeFocusIfDue()
        scheduleFocusCompletion()
        resolvePendingEvent()
        WidgetCenter.shared.reloadAllTimelines()
    }
    /// The selected month and the current month, widened to whole weeks plus a week either side,
    /// so week strips and the month grid's leading/trailing days always have their events.
    nonisolated static func loadInterval(selected: Date, now: Date, calendar: Calendar = .current) -> DateInterval {
        let months = [selected, now].map { calendar.dateInterval(of: .month, for: $0)! }
        let firstWeek = calendar.dateInterval(of: .weekOfYear, for: months.map(\.start).min()!)!.start
        let lastWeek = calendar.dateInterval(of: .weekOfYear, for: months.map(\.end).max()!.addingTimeInterval(-1))!.end
        return DateInterval(start: calendar.date(byAdding: .day, value: -7, to: firstWeek)!, end: calendar.date(byAdding: .day, value: 7, to: lastWeek)!)
    }
    func events(on date: Date) -> [CalendarEvent] {
        let interval = Calendar.current.dateInterval(of: .day, for: date)!
        return events.filter { $0.startDate < interval.end && $0.endDate > interval.start }
    }
    func requestCalendar() async {
        persist()
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
    /// A setup sheet asked for the paywall; present it once the sheet is gone (sheets cannot stack).
    var paywallAfterSheet = false

    /// Free: one setup, and no premium sky or kind added beyond what the setup already had.
    func canSave(_ setup: LockSetup) -> Bool {
        if purchases.isPremium { return true }
        let stored = setups.first { $0.id == setup.id }
        if stored == nil && !setups.isEmpty { return false }
        return !setup.addsPremium(over: stored)
    }

    /// Saves (inserts or replaces) a setup. Free: one setup, free skies and kinds only.
    @discardableResult
    func saveSetup(_ setup: LockSetup) -> Bool {
        guard canSave(setup) else { showPaywall = true; return false }
        guard setup.isValid else { return false }
        if let index = setups.firstIndex(where: { $0.id == setup.id }) { setups[index] = setup } else { setups.append(setup) }
        if activeSetupID == nil { activeSetupID = setup.id }
        do {
            try storage.write(setups, key: "setups.v2")
            try storage.write(activeSetupID?.uuidString ?? "", key: "activeSetup.v2")
            WidgetCenter.shared.reloadAllTimelines()
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func removeSetup(_ id: UUID) {
        setups.removeAll { $0.id == id }
        if activeSetupID == id { activeSetupID = setups.first?.id }
        do {
            try storage.write(setups, key: "setups.v2")
            try storage.write(activeSetupID?.uuidString ?? "", key: "activeSetup.v2")
            WidgetCenter.shared.reloadAllTimelines()
        } catch { self.error = error.localizedDescription }
    }
    func activateSetup(_ id: UUID) {
        activeSetupID = id
        do { try storage.write(id.uuidString, key: "activeSetup.v2"); WidgetCenter.shared.reloadAllTimelines() }
        catch { self.error = error.localizedDescription }
    }
    /// Finishes onboarding: the chosen rituals replace the untouched v1 sample habits (or join real ones),
    /// a free starter setup exists, and the flag is saved. Fixture mode changes memory only.
    func completeOnboarding(rituals: [Habit], fixture: Bool = false) {
        let untouchedSamples = habits.map(\.id) == MockData.habits.map(\.id) && habits.allSatisfy { $0.completedDates.isEmpty }
        // Picking none keeps the samples, so Day never opens with an empty ring.
        if untouchedSamples, !rituals.isEmpty {
            habits = rituals
        } else {
            for ritual in rituals where !habits.contains(where: { $0.title.caseInsensitiveCompare(ritual.title) == .orderedSame }) {
                habits.append(ritual)
            }
        }
        if setups.isEmpty {
            let starter = LockSetup.starter(name: String(localized: "My Halo"), sky: settings.skyID.isPremium && !purchases.isPremium ? .livingSky : settings.skyID)
            setups = [starter]
            activeSetupID = starter.id
        }
        settings.hasCompletedOnboarding = true
        guard !fixture else { return }
        do {
            try storage.write(habits, key: "habits")
            try storage.write(setups, key: "setups.v2")
            try storage.write(activeSetupID?.uuidString ?? "", key: "activeSetup.v2")
        } catch { self.error = error.localizedDescription }
        persist()
    }

    func applySky(_ sky: SkyID) {
        guard !sky.isPremium || purchases.isPremium else { showSettings = false; showPaywall = true; return }
        settings.skyChoice = sky
        persist()
    }
    /// Turns the location-matched sky on or off. Returns a message to show in place (not via the global alert,
    /// which would dismiss Settings). Unsaved edits are persisted first: the permission prompt triggers a refresh.
    func useLocationForSky(_ enabled: Bool) async -> String? {
        persist()
        guard enabled else { settings.approxCoordinate = nil; persist(); return nil }
        do {
            settings.approxCoordinate = try await location.approximateCoordinate()
            persist()
            return nil
        } catch {
            return error.localizedDescription
        }
    }
    func removeCountdown(_ id: UUID) {
        countdowns.removeAll { $0.id == id }
        do { try storage.write(countdowns, key: "countdowns"); WidgetCenter.shared.reloadAllTimelines() } catch { self.error = error.localizedDescription }
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
            if purchases.isPremium && settings.liveActivities { try await activities.start(focus: session, sky: settings.skyID) }
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
        syncEndedFocus()
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
    /// A widget or Live Activity may have ended the session (and recorded it) while the app wasn't looking.
    private func syncEndedFocus() {
        guard let stored = storage.focus, let current = focus, stored.id == current.id, current.isActive, !stored.isActive else { return }
        focus = stored
        focusHistory = storage.read("focusHistory", fallback: [])
    }

    /// An event deep link that arrived before events loaded (cold launch from a widget).
    var pendingEventID: String?
    func resolvePendingEvent() {
        guard let id = pendingEventID, let event = events.first(where: { $0.id == id }) else { return }
        pendingEventID = nil
        selectedEvent = event
    }

    func stopFocus(completed: Bool = false) async {
        focusTimer?.cancel()
        syncEndedFocus()
        if var session = focus, session.isActive {
            session.isActive = false
            if !completed { session.endDate = .now }
            focus = session; focusHistory.insert(session, at: 0)
            do { try storage.write(session, key: "focus"); try storage.write(focusHistory, key: "focusHistory") } catch { self.error = error.localizedDescription }
        }
        if completed { await activities.finish() } else { await activities.end() }
        do { try await notifications.plan(events: events, focus: nil, minutes: settings.eventReminderMinutes) } catch { self.error = error.localizedDescription }
        WidgetCenter.shared.reloadAllTimelines()
    }
    func countDown(_ event: CalendarEvent) async {
        guard purchases.isPremium else { showPaywall = true; return }
        if focus?.isActive == true { await stopFocus() }
        do { try await activities.eventCountdown(event, sky: settings.skyID) } catch { self.error = error.localizedDescription }
    }
    func route(_ url: URL) {
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        switch url.host {
        case "calendar", "day":
            let date = query?.first(where: { $0.name == "date" })?.value.flatMap { value -> Date? in
                // Deep-link dates are always Gregorian ISO days, whatever the device calendar.
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.calendar = Calendar(identifier: .gregorian)
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.date(from: value)
            }
            tab = .day
            dayZoom = url.host == "calendar" ? .month : .day
            // Today is shown by following the clock (viewedDay = nil), never as a pinned date.
            if url.host == "day" || date != nil { viewedDay = date.flatMap { Calendar.current.isDateInToday($0) ? nil : $0 } }
            if let date { selectedDate = date }
        case "studio": tab = .studio
        case "rituals", "you": tab = .you
        case "focus": tab = .day; showFocus = true
        case "paywall": showPaywall = true
        case "event":
            tab = .day
            pendingEventID = query?.first(where: { $0.name == "id" })?.value ?? url.lastPathComponent
            resolvePendingEvent()
        default: tab = .day; dayZoom = .day; viewedDay = nil
        }
    }
}
