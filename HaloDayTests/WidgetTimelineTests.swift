import XCTest
@testable import HaloDay

final class WidgetTimelineTests: XCTestCase {
    private let calendar = Calendar.current
    private var day: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 5))! }
    private func at(_ hour: Double) -> Date { day.addingTimeInterval(hour * 3600) }
    private func event(_ id: String, _ start: Double, _ end: Double) -> CalendarEvent {
        CalendarEvent(id: id, title: id, startDate: at(start), endDate: at(end), calendarName: "x", accentColor: "5B74D6")
    }

    func testEntriesFallOnFutureEventBoundariesAndMidnight() {
        let events = [event("a", 9, 9.5), event("b", 10.5, 11.25), event("late", 23, 25)]
        let dates = WidgetTimeline.entryDates(now: at(10.08), events: events, focus: nil, hourly: false, calendar: calendar)
        XCTAssertEqual(dates.first, at(10.08))
        XCTAssertTrue(dates.contains(at(10.5)))
        XCTAssertTrue(dates.contains(at(11.25)))
        XCTAssertTrue(dates.contains(at(23)))
        XCTAssertTrue(dates.contains(at(24)))
        XCTAssertFalse(dates.contains(at(9.5)))
        XCTAssertFalse(dates.contains(at(25)))
        XCTAssertEqual(dates, dates.sorted())
        XCTAssertEqual(Set(dates).count, dates.count)
    }
    func testRunningFocusEndIsAnEntryAndPausedIsNot() {
        let running = FocusSession(title: "f", startDate: at(10), endDate: at(10.75), durationMinutes: 45, accentColor: "D4AF6A")
        XCTAssertTrue(WidgetTimeline.entryDates(now: at(10.08), events: [], focus: running, hourly: false, calendar: calendar).contains(at(10.75)))
        var paused = running; paused.pausedRemaining = 600
        XCTAssertFalse(WidgetTimeline.entryDates(now: at(10.08), events: [], focus: paused, hourly: false, calendar: calendar).contains(at(10.75)))
    }
    func testHourlyEntriesForSkyBackgroundsStayBounded() {
        let dates = WidgetTimeline.entryDates(now: at(10.08), events: (0..<20).map { event("e\($0)", 10.5 + Double($0) * 0.5, 10.75 + Double($0) * 0.5) }, focus: nil, hourly: true, calendar: calendar)
        XCTAssertTrue(dates.contains(at(11)))
        XCTAssertTrue(dates.contains(at(23)))
        XCTAssertLessThanOrEqual(dates.count, 60)
        XCTAssertLessThanOrEqual(dates.last ?? .distantFuture, at(24))
    }
    func testSnapshotFallsBackToStarterSetupAndSampleEvents() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let snapshot = WidgetSnapshot.load(storage: AppGroupStorage(directory: directory), date: at(10), setupID: nil)
        XCTAssertTrue(snapshot.data.isSample)
        XCTAssertFalse(snapshot.data.timedToday.isEmpty)
        XCTAssertTrue(snapshot.setup.isValid)
        XCTAssertFalse(snapshot.isPremium)
    }
    func testWidgetsDeepLinkIntoTheV2Tabs() {
        let data = WidgetData(date: at(10.08), events: [event("review", 10.5, 11.25)], habits: [], focus: nil, countdown: nil, isSample: false)
        XCTAssertEqual(WidgetKind.orbit.url(for: data).absoluteString, "haloday://day")
        XCTAssertEqual(WidgetKind.nextUp.url(for: data).absoluteString, "haloday://event/review")
        XCTAssertEqual(WidgetKind.countdown.url(for: data).absoluteString, "haloday://you")
        XCTAssertEqual(WidgetKind.month.url(for: data).absoluteString, "haloday://calendar")
        let empty = WidgetData(date: at(10.08), events: [], habits: [], focus: nil, countdown: nil, isSample: false)
        XCTAssertEqual(WidgetKind.nextUp.url(for: empty).absoluteString, "haloday://day")
    }
}

final class EndFocusStorageTests: XCTestCase {
    func testEndingFocusFromTheWidgetRecordsHistory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = AppGroupStorage(directory: directory)
        let start = Date(timeIntervalSince1970: 1_791_170_000)
        try storage.write(FocusSession(title: "Write", startDate: start, endDate: start.addingTimeInterval(1500), durationMinutes: 25, accentColor: "D4AF6A"), key: "focus")
        try storage.endFocus(at: start.addingTimeInterval(600))
        XCTAssertEqual(storage.focus?.isActive, false)
        let history: [FocusSession] = storage.read("focusHistory", fallback: [])
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].endDate, start.addingTimeInterval(600))
        try storage.endFocus(at: start.addingTimeInterval(700))
        XCTAssertEqual((storage.read("focusHistory", fallback: []) as [FocusSession]).count, 1, "ending twice records once")
    }
}
