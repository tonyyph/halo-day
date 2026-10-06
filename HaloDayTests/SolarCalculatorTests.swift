import XCTest
@testable import HaloDay

final class SolarCalculatorTests: XCTestCase {
    private let london = GeoCoordinate(latitude: 51.5074, longitude: -0.1278)
    private let tromso = GeoCoordinate(latitude: 69.6492, longitude: 18.9553)

    private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }
    private func calendar(_ id: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: id)!; return calendar
    }
    private func assertSun(_ day: SolarDay, sunrise: String, sunset: String, file: StaticString = #filePath, line: UInt = #line) {
        guard case let .normal(rise, set) = day else { return XCTFail("expected a normal day, got \(day)", file: file, line: line) }
        XCTAssertEqual(rise.timeIntervalSince1970, date(sunrise).timeIntervalSince1970, accuracy: 120, file: file, line: line)
        XCTAssertEqual(set.timeIntervalSince1970, date(sunset).timeIntervalSince1970, accuracy: 120, file: file, line: line)
    }

    func testLondonSolsticesMatchPublishedTimes() {
        // Published: 21 Jun 2026 sunrise 04:43 BST, sunset 21:21 BST; 21 Dec 2026 sunrise 08:04 GMT, sunset 15:54 GMT.
        assertSun(SolarCalculator.day(containing: date("2026-06-21T12:00:00Z"), coordinate: london, calendar: calendar("Europe/London")),
                  sunrise: "2026-06-21T03:43:00Z", sunset: "2026-06-21T20:21:00Z")
        assertSun(SolarCalculator.day(containing: date("2026-12-21T12:00:00Z"), coordinate: london, calendar: calendar("Europe/London")),
                  sunrise: "2026-12-21T08:04:00Z", sunset: "2026-12-21T15:54:00Z")
    }
    func testEquatorEquinoxDayIsJustOverTwelveHours() {
        let day = SolarCalculator.day(containing: date("2026-03-20T12:00:00Z"), coordinate: GeoCoordinate(latitude: 0, longitude: 0), calendar: calendar("UTC"))
        guard case let .normal(rise, set) = day else { return XCTFail() }
        XCTAssertEqual(set.timeIntervalSince(rise) / 60, 727, accuracy: 4)
    }
    func testDayIsAnchoredToTheLocalCalendarDayFarFromGreenwich() {
        let day = SolarCalculator.day(containing: date("2026-10-05T03:05:00Z"), coordinate: GeoCoordinate(latitude: 21.0285, longitude: 105.8542), calendar: calendar("Asia/Ho_Chi_Minh"))
        guard case let .normal(rise, set) = day else { return XCTFail() }
        let hanoi = calendar("Asia/Ho_Chi_Minh")
        XCTAssertEqual(hanoi.component(.day, from: rise), 5)
        XCTAssertEqual(hanoi.component(.hour, from: rise), 5)
        XCTAssertEqual(hanoi.component(.hour, from: set), 17)
    }
    func testPolarNightAndPolarDay() {
        XCTAssertEqual(SolarCalculator.day(containing: date("2026-12-21T12:00:00Z"), coordinate: tromso, calendar: calendar("Europe/Oslo")), .polarNight)
        XCTAssertEqual(SolarCalculator.day(containing: date("2026-06-21T12:00:00Z"), coordinate: tromso, calendar: calendar("Europe/Oslo")), .polarDay)
        for hour in stride(from: 0, to: 24, by: 3) {
            let altitude = SolarCalculator.sunAltitude(at: date("2026-12-21T00:00:00Z").addingTimeInterval(Double(hour) * 3600), coordinate: tromso)
            XCTAssertFalse(altitude.isNaN); XCTAssertLessThan(altitude, 0)
        }
    }
    func testNoonAltitudeInLondonAtSummerSolstice() {
        XCTAssertEqual(SolarCalculator.sunAltitude(at: date("2026-06-21T12:02:00Z"), coordinate: london), 61.9, accuracy: 0.3)
        XCTAssertLessThan(SolarCalculator.sunAltitude(at: date("2026-06-21T00:00:00Z"), coordinate: london), -10)
    }
    func testMoonPhaseAtKnownNewAndFullMoons() {
        // Full moon (total lunar eclipse) 3 Mar 2026 11:38 UTC; new moon (annular eclipse) 17 Feb 2026 12:01 UTC.
        XCTAssertEqual(SolarCalculator.moonPhase(at: date("2026-03-03T11:38:00Z")), 0.5, accuracy: 0.03)
        let new = SolarCalculator.moonPhase(at: date("2026-02-17T12:01:00Z"))
        XCTAssertLessThan(min(new, 1 - new), 0.03)
    }
}
