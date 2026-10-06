import XCTest
@testable import HaloDay

final class TimeZoneLocatorTests: XCTestCase {
    func testKnownZoneUsesItsCity() {
        let coordinate = TimeZoneLocator.approximateCoordinate(for: TimeZone(identifier: "Asia/Ho_Chi_Minh")!)
        XCTAssertEqual(coordinate.latitude, 10.82, accuracy: 0.01)
        XCTAssertEqual(coordinate.longitude, 106.63, accuracy: 0.01)
    }
    func testLegacyAliasResolves() {
        XCTAssertEqual(TimeZoneLocator.approximateCoordinate(for: TimeZone(identifier: "Asia/Saigon")!).latitude, 10.82, accuracy: 0.01)
    }
    func testUnknownZoneFallsBackToOffsetOnTheEquator() {
        let coordinate = TimeZoneLocator.approximateCoordinate(for: TimeZone(secondsFromGMT: 3 * 3600)!)
        XCTAssertEqual(coordinate.latitude, 0)
        XCTAssertEqual(coordinate.longitude, 45, accuracy: 0.01)
    }
}
