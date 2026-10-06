import XCTest
@testable import HaloDay

final class SkyEngineTests: XCTestCase {
    private let places: [(String, GeoCoordinate, String, String)] = [
        ("Hanoi", GeoCoordinate(latitude: 21.03, longitude: 105.85), "Asia/Ho_Chi_Minh", "2026-10-05T00:00:00+07:00"),
        ("London summer", GeoCoordinate(latitude: 51.51, longitude: -0.13), "Europe/London", "2026-06-21T00:00:00+01:00"),
        ("Tromsø winter", GeoCoordinate(latitude: 69.65, longitude: 18.96), "Europe/Oslo", "2026-12-21T00:00:00+01:00")
    ]
    private func calendar(_ id: String) -> Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: id)!; return c }

    func testEveryMinuteIsLegibleForPrimaryAndSecondaryText() {
        for sky in SkyID.allCases {
            for (name, coordinate, zone, midnight) in places {
                let start = ISO8601DateFormatter().date(from: midnight)!
                for minute in stride(from: 0, to: 1440, by: 10) {
                    let state = SkyEngine.state(sky: sky, at: start.addingTimeInterval(Double(minute) * 60), coordinate: coordinate, calendar: calendar(zone))
                    for stop in state.stops {
                        let secondary = state.inkColor.composited(over: stop, opacity: SkyEngine.secondaryOpacity)
                        XCTAssertGreaterThanOrEqual(SkyColor.contrast(state.inkColor, stop), 4.5, "\(sky) \(name) minute \(minute)")
                        XCTAssertGreaterThanOrEqual(SkyColor.contrast(secondary, stop), 4.5, "\(sky) \(name) minute \(minute) secondary")
                    }
                }
            }
        }
    }
    func testLivingSkyChangesContinuouslyBetweenInkFlips() {
        let (_, coordinate, zone, midnight) = places[0]
        let start = ISO8601DateFormatter().date(from: midnight)!
        var previous = SkyEngine.state(sky: .livingSky, at: start, coordinate: coordinate, calendar: calendar(zone))
        for minute in 1..<1440 {
            let state = SkyEngine.state(sky: .livingSky, at: start.addingTimeInterval(Double(minute) * 60), coordinate: coordinate, calendar: calendar(zone))
            if state.ink == previous.ink {
                XCTAssertLessThan(abs(state.mid.luminance - previous.mid.luminance), 0.02, "jump at minute \(minute)")
            }
            previous = state
        }
    }
    func testMomentsFollowTheSunInHanoi() {
        let (_, coordinate, zone, _) = places[0]
        let formatter = ISO8601DateFormatter()
        func moment(_ time: String) -> SkyMoment {
            SkyEngine.state(sky: .livingSky, at: formatter.date(from: "2026-10-05T\(time):00+07:00")!, coordinate: coordinate, calendar: calendar(zone)).moment
        }
        XCTAssertEqual(moment("02:00"), .night)
        XCTAssertEqual(moment("05:42"), .dawn)
        XCTAssertEqual(moment("10:05"), .morning)
        XCTAssertEqual(moment("12:30"), .midday)
        XCTAssertEqual(moment("15:30"), .afternoon)
        XCTAssertEqual(moment("17:15"), .goldenHour)
        XCTAssertEqual(moment("17:50"), .dusk)
        XCTAssertEqual(moment("22:30"), .night)
    }
    func testInkMatchesDaylightAndFixedSkiesIgnoreTheSun() {
        let (_, coordinate, zone, _) = places[0]
        let noon = ISO8601DateFormatter().date(from: "2026-10-05T12:00:00+07:00")!
        let night = ISO8601DateFormatter().date(from: "2026-10-05T23:00:00+07:00")!
        XCTAssertEqual(SkyEngine.state(sky: .livingSky, at: noon, coordinate: coordinate, calendar: calendar(zone)).ink, .dark)
        XCTAssertEqual(SkyEngine.state(sky: .livingSky, at: night, coordinate: coordinate, calendar: calendar(zone)).ink, .light)
        let celestialNoon = SkyEngine.state(sky: .celestial, at: noon, coordinate: coordinate, calendar: calendar(zone))
        let celestialNight = SkyEngine.state(sky: .celestial, at: night, coordinate: coordinate, calendar: calendar(zone))
        XCTAssertEqual(celestialNoon.mid, celestialNight.mid)
        XCTAssertEqual(celestialNoon.ink, .light)
        XCTAssertEqual(SkyEngine.state(sky: .instrument, at: night, coordinate: coordinate, calendar: calendar(zone)).ink, .dark)
        XCTAssertNotEqual(celestialNoon.moment, celestialNight.moment, "moment always follows the real sun")
    }
    func testCatalogTiers() {
        XCTAssertEqual(SkyID.allCases.filter { !$0.isPremium }, [.livingSky, .celestial])
        XCTAssertEqual(SkyID.instrument.orbitStyle, .engraved)
        XCTAssertEqual(SkyID.mist.orbitStyle, .ink)
    }
}
