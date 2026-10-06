import XCTest
@testable import HaloDay

@MainActor
final class NavigationTests: XCTestCase {
    func testDeepLinksLandOnV2Tabs() {
        let model = HaloModel()
        model.route(URL(string: "haloday://focus")!)
        XCTAssertEqual(model.tab, .day); XCTAssertTrue(model.showFocus)
        model.route(URL(string: "haloday://rituals")!)
        XCTAssertEqual(model.tab, .you)
        model.route(URL(string: "haloday://studio")!)
        XCTAssertEqual(model.tab, .studio)
        model.route(URL(string: "haloday://calendar?date=2026-10-20")!)
        XCTAssertEqual(model.tab, .day)
        XCTAssertEqual(model.dayZoom, .month)
        XCTAssertEqual(model.viewedDay.map { Calendar.current.component(.day, from: $0) }, 20)
        model.route(URL(string: "haloday://today")!)
        XCTAssertEqual(model.tab, .day)
        XCTAssertEqual(model.dayZoom, .day)
        XCTAssertNil(model.viewedDay)
        model.route(URL(string: "haloday://paywall")!)
        XCTAssertTrue(model.showPaywall)
    }
}
