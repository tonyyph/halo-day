import XCTest
@testable import HaloDay

/// Regressions found in the Phase 3 whole-branch review.
@MainActor
final class ZoomReviewTests: XCTestCase {
    // I2: the loaded interval covers whole weeks around the month, so the first week's leading days have events.
    func testLoadIntervalCoversWholeWeeksAroundTheMonth() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2
        let october20 = calendar.date(from: DateComponents(year: 2026, month: 10, day: 20))!
        let interval = HaloModel.loadInterval(selected: october20, now: october20, calendar: calendar)
        XCTAssertEqual(interval.start, calendar.date(from: DateComponents(year: 2026, month: 9, day: 21))!)
        XCTAssertEqual(interval.end, calendar.date(from: DateComponents(year: 2026, month: 11, day: 9))!)
    }
    // Minor 2 → Important: a deep link to today follows today (no stray "Today" pill).
    func testDeepLinkToTodayFollowsToday() {
        let model = HaloModel()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        model.route(URL(string: "haloday://calendar?date=\(formatter.string(from: .now))")!)
        XCTAssertNil(model.viewedDay)
        XCTAssertEqual(model.dayZoom, .month)
    }
}
