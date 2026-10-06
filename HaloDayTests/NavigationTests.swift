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
        XCTAssertEqual(model.tab, .calendar)
        XCTAssertEqual(Calendar.current.component(.day, from: model.selectedDate), 20)
        model.route(URL(string: "haloday://today")!)
        XCTAssertEqual(model.tab, .day)
        model.route(URL(string: "haloday://paywall")!)
        XCTAssertTrue(model.showPaywall)
    }
}
