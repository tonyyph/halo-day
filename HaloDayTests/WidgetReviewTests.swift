import XCTest
@testable import HaloDay

/// Regressions found in the Phase 6 whole-branch review.
@MainActor
final class WidgetReviewTests: XCTestCase {
    private let calendar = Calendar.current
    private var day: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 5))! }
    private func at(_ hour: Double) -> Date { day.addingTimeInterval(hour * 3600) }

    // I1: a session ended from the Live Activity keeps its early end and is recorded once.
    func testFocusEndedFromTheIslandIsRecordedOnceWithItsRealEnd() async throws {
        let storage = AppGroupStorage.shared
        let savedFocus = storage.focus
        let savedHistory: [FocusSession] = storage.read("focusHistory", fallback: [])
        defer {
            try? storage.write(savedFocus, key: "focus")
            try? storage.write(savedHistory, key: "focusHistory")
        }
        try storage.write([FocusSession](), key: "focusHistory")
        let start = Date.now.addingTimeInterval(-600)
        let session = FocusSession(title: "Write", startDate: start, endDate: start.addingTimeInterval(1500), durationMinutes: 25, accentColor: "D4AF6A")
        try storage.write(session, key: "focus")
        let model = HaloModel()
        model.focus = session
        try storage.endFocus(at: start.addingTimeInterval(600))
        await model.stopFocus()
        let history: [FocusSession] = storage.read("focusHistory", fallback: [])
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.endDate, start.addingTimeInterval(600))
        XCTAssertEqual(model.focusHistory.filter { $0.id == session.id }.count, 1)
    }
    // I2: without the sky behind it (StandBy, tinted/clear Home Screen) the ink turns light.
    func testInkIsLightWhenTheSkyBackgroundIsRemoved() {
        let noon = SkyEngine.state(sky: .livingSky, at: at(12), coordinate: GeoCoordinate(latitude: 21.03, longitude: 105.85))
        XCTAssertEqual(noon.ink, .dark)
        XCTAssertEqual(HomeWidgetView.ink(for: noon, backgroundVisible: true), noon.inkColor)
        XCTAssertEqual(HomeWidgetView.ink(for: noon, backgroundVisible: false), SkyEngine.lightInk)
    }
    // I3: "In N min" stays fresh — five-minute entries in the 90 minutes before the next event.
    func testEntriesTickBeforeTheNextEvent() {
        let review = CalendarEvent(id: "r", title: "r", startDate: at(10.5), endDate: at(11.25), calendarName: "x", accentColor: "5B74D6")
        let dates = WidgetTimeline.entryDates(now: at(9.25), events: [review], focus: nil, hourly: false, calendar: calendar)
        for minutes in [5, 30, 60, 70] {
            XCTAssertTrue(dates.contains(at(10.5).addingTimeInterval(Double(-minutes) * 60)), "\(minutes) min before")
        }
        XCTAssertFalse(dates.contains(where: { $0 < at(9.25) }))
    }
    // I4: after a pause/resume the ring measures against the planned length, not the stretched interval.
    func testActivityRingIgnoresPausedTime() {
        let start = at(10)
        let attributes = HaloActivityAttributes(title: "f", startDate: start, endDate: start.addingTimeInterval(1500), themeId: "livingSky", accentColor: "D4AF6A")
        let resumed = HaloActivityAttributes.ContentState(endDate: start.addingTimeInterval(1500 + 1800), phase: "running")
        let interval = FocusActivityView.ringInterval(attributes: attributes, state: resumed)
        XCTAssertEqual(interval.upperBound, resumed.endDate)
        XCTAssertEqual(interval.upperBound.timeIntervalSince(interval.lowerBound), 1500, accuracy: 0.001)
        XCTAssertEqual(FocusActivityView.phase(attributes: attributes, state: resumed, isStale: true), .finished)
        XCTAssertEqual(FocusActivityView.phase(attributes: attributes, state: .init(endDate: resumed.endDate, pausedRemaining: 300, phase: "paused"), isStale: false), .paused)
    }
    // I5: a Next up tap on a cold launch opens the event once events load; ids with "/" and ":" survive.
    func testEventDeepLinkWaitsForEventsAndKeepsOddIDs() {
        let id = "ABC:123/DEF-1791170000.0"
        let event = CalendarEvent(id: id, title: "Review", startDate: at(10.5), endDate: at(11.25), calendarName: "x", accentColor: "5B74D6")
        let url = WidgetKind.nextUp.url(for: WidgetData(date: at(10), events: [event], habits: [], focus: nil, countdown: nil, isSample: false))
        let model = HaloModel()
        model.events = []
        model.route(url)
        XCTAssertNil(model.selectedEvent)
        model.events = [event]
        model.resolvePendingEvent()
        XCTAssertEqual(model.selectedEvent?.id, id)
    }
    // Minor → Important: the nearest future countdown is shown, never a past one.
    func testWidgetsPickTheNearestFutureCountdown() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = AppGroupStorage(directory: directory)
        try storage.write([Countdown(title: "Past", targetDate: at(-48)), Countdown(title: "Far", targetDate: at(24 * 40)), Countdown(title: "Soon", targetDate: at(24 * 3))], key: "countdowns")
        XCTAssertEqual(WidgetSnapshot.load(storage: storage, date: at(10), setupID: nil).data.countdown?.title, "Soon")
    }
}

final class DaysLeftTests: XCTestCase {
    func testEnglishAgreesInNumber() throws {
        try XCTSkipUnless(Locale.current.language.languageCode == .english)
        XCTAssertEqual(DaysLeft.string(1), "1 day left")
        XCTAssertEqual(DaysLeft.string(12), "12 days left")
    }
}
