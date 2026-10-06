import XCTest
@testable import HaloDay

/// Regressions found in the Phase 2 whole-branch review.
@MainActor
final class DayReviewTests: XCTestCase {
    private func session(endingIn seconds: TimeInterval, paused: Bool = false) -> FocusSession {
        let end = Date.now.addingTimeInterval(seconds)
        return FocusSession(title: "Write", startDate: end.addingTimeInterval(-1500), endDate: end, durationMinutes: 25, accentColor: "D4AF6A",
                            pausedRemaining: paused ? 300 : nil)
    }

    // I1: a session that ends while the app is open completes and celebrates, wherever the cover is.
    func testDueFocusCompletesAndCelebrates() async {
        let model = HaloModel()
        model.focus = session(endingIn: -20)
        await model.completeFocusIfDue(now: .now)
        XCTAssertEqual(model.focus?.isActive, false)
        XCTAssertNotNil(model.completedFocus)
        XCTAssertTrue(model.showFocus)
    }
    // I2: a session that ended long ago (app was closed) completes quietly.
    func testStaleFocusCompletesWithoutCelebration() async {
        let model = HaloModel()
        model.focus = session(endingIn: -7200)
        await model.completeFocusIfDue(now: .now)
        XCTAssertEqual(model.focus?.isActive, false)
        XCTAssertNil(model.completedFocus)
        XCTAssertFalse(model.showFocus)
    }
    func testPausedFocusNeverCompletes() async {
        let model = HaloModel()
        model.focus = session(endingIn: -20, paused: true)
        await model.completeFocusIfDue(now: .now)
        XCTAssertEqual(model.focus?.isActive, true)
    }
    // C2/I2: the cover opens once at launch, only for a session that is still running or paused.
    func testRunningFocusIsPresentedOnLaunchOnly() {
        let model = HaloModel()
        model.focus = session(endingIn: 600)
        model.presentRunningFocus(now: .now)
        XCTAssertTrue(model.showFocus)
        model.showFocus = false
        model.focus = session(endingIn: -60)
        model.presentRunningFocus(now: .now)
        XCTAssertFalse(model.showFocus)
    }
    // Minor→Important: 12-hour locales keep AM/PM on the Orbit clock.
    func testClockKeepsTheLocaleHourCycle() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 22, minute: 30))!
        XCTAssertTrue(DayClock.string(date, locale: Locale(identifier: "en_US"), timeZone: calendar.timeZone).contains("PM"))
        XCTAssertEqual(DayClock.string(date, locale: Locale(identifier: "vi_VN"), timeZone: calendar.timeZone), "22:30")
    }
    // I4: deep links set or reset the day being viewed.
    func testDayDeepLinksControlTheViewedDay() {
        let model = HaloModel()
        model.route(URL(string: "haloday://day?date=2026-10-20")!)
        XCTAssertEqual(model.viewedDay.map { Calendar.current.component(.day, from: $0) }, 20)
        model.route(URL(string: "haloday://today")!)
        XCTAssertNil(model.viewedDay)
    }
}
