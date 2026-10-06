import XCTest
import SwiftUI
@testable import HaloDay

/// Regressions found in the Phase 1 whole-branch review.
final class ReviewRegressionTests: XCTestCase {
    private func calendar(_ id: String) -> Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: id)!; return c }
    private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    // Finding 1: short subpolar nights must not paint the whole ring as night.
    func testReykjavikMidsummerNightSpanIsOnlyTheEarlyMorning() {
        let reykjavik = calendar("Atlantic/Reykjavik")
        let day = SolarCalculator.day(containing: date("2026-06-21T12:00:00Z"), coordinate: GeoCoordinate(latitude: 64.15, longitude: -21.94), calendar: reykjavik)
        let spans = OrbitGeometry.nightSpans(day, calendar: reykjavik)
        XCTAssertEqual(spans.count, 1, "\(spans)")
        XCTAssertEqual(spans.first?.lowerBound, 0)
        XCTAssertEqual(spans.first?.upperBound ?? 0, 2.9, accuracy: 0.3)
    }

    // Finding 2: DST transition days use wall-clock hours.
    func testDaylightSavingDaysPlaceEventsOnWallClockHours() {
        let london = calendar("Europe/London")
        for dayString in ["2026-10-25", "2026-03-29"] {
            let day = london.date(from: DateComponents(year: Int(dayString.prefix(4)), month: Int(dayString.dropFirst(5).prefix(2)), day: Int(dayString.suffix(2))))!
            func at(_ hour: Int, _ minute: Int) -> Date { london.date(bySettingHour: hour, minute: minute, second: 0, of: day)! }
            let layout = OrbitLayout(day: day, events: [
                CalendarEvent(id: "lunch", title: "Lunch", startDate: at(12, 0), endDate: at(13, 0), calendarName: "x", accentColor: "E2607D"),
                CalendarEvent(id: "late", title: "Late", startDate: at(23, 30), endDate: at(23, 55), calendarName: "x", accentColor: "E2607D")
            ], calendar: london)
            let byID = Dictionary(uniqueKeysWithValues: layout.arcs.map { ($0.id, $0) })
            XCTAssertEqual(byID["lunch"]!.start, 12, accuracy: 0.001, dayString)
            XCTAssertEqual(byID["lunch"]!.end, 13, accuracy: 0.001, dayString)
            XCTAssertEqual(byID["late"]!.start, 23.5, accuracy: 0.001, dayString)
            XCTAssertLessThanOrEqual(byID["late"]!.end, 24, dayString)
            XCTAssertGreaterThan(byID["late"]!.end, byID["late"]!.start, dayString)
        }
    }

    // Finding 3: every lane and overflow marker stays inside the Orbit's square.
    func testOuterLaneFitsInsideTheFrame() {
        let metrics = OrbitMetrics(size: 300)
        XCTAssertLessThanOrEqual(metrics.laneRadius(2) + metrics.trackWidth / 2, 150 - 4)
    }
    @MainActor
    func testCrowdedOrbitDrawsNothingOutsideItsFrame() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "UTC")!
        let day = calendar.startOfDay(for: date("2026-10-05T12:00:00Z"))
        let events = (0..<6).map { i in
            CalendarEvent(id: "e\(i)", title: "e", startDate: day.addingTimeInterval(9 * 3600 + Double(i) * 600),
                          endDate: day.addingTimeInterval(11 * 3600), calendarName: "x", accentColor: "E2607D")
        }
        let content = OrbitContent(layout: OrbitLayout(day: day, events: events, calendar: calendar), nowHour: nil)
        let sky = SkyEngine.state(sky: .celestial, at: day, coordinate: GeoCoordinate(latitude: 0, longitude: 0), calendar: calendar)
        let renderer = ImageRenderer(content: OrbitCanvas(content: content, sky: sky, style: .glow).frame(width: 200, height: 200).frame(width: 300, height: 300))
        let image = try XCTUnwrap(renderer.cgImage)
        let width = image.width, height = image.height, scale = width / 300
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var outside = 0
        for y in 0..<height { for x in 0..<width where !(50 * scale..<250 * scale).contains(x) || !(50 * scale..<250 * scale).contains(y) {
            if data[(y * width + x) * 4 + 3] > 8 { outside += 1 }
        } }
        XCTAssertEqual(outside, 0)
    }

    // Finding 4: no colour snap at solar noon / midnight away from the tropics.
    func testSkyIsContinuousAtCulminationAtHighLatitudes() {
        let cases: [(GeoCoordinate, String, String)] = [
            (GeoCoordinate(latitude: 51.51, longitude: -0.13), "Europe/London", "2026-12-21T00:00:00Z"),
            (GeoCoordinate(latitude: 59.91, longitude: 10.75), "Europe/Oslo", "2026-06-21T00:00:00+02:00"),
            (GeoCoordinate(latitude: 69.65, longitude: 18.96), "Europe/Oslo", "2026-02-10T00:00:00+01:00")
        ]
        for (coordinate, zone, midnight) in cases {
            let start = date(midnight)
            var previous = SkyEngine.state(sky: .livingSky, at: start, coordinate: coordinate, calendar: calendar(zone))
            for minute in 1..<1440 {
                let state = SkyEngine.state(sky: .livingSky, at: start.addingTimeInterval(Double(minute) * 60), coordinate: coordinate, calendar: calendar(zone))
                if state.ink == previous.ink {
                    for (a, b) in zip(state.stops, previous.stops) {
                        XCTAssertLessThan(abs(a.luminance - b.luminance), 0.02, "\(zone) \(midnight) minute \(minute)")
                    }
                }
                previous = state
            }
        }
    }

    // Finding 5: polar night holds the night phase; polar day holds daylight.
    func testPolarDaysHoldTheirPhase() {
        let tromso = GeoCoordinate(latitude: 69.65, longitude: 18.96)
        for minute in stride(from: 0, to: 1440, by: 10) {
            let winter = SkyEngine.state(sky: .livingSky, at: date("2026-12-21T00:00:00+01:00").addingTimeInterval(Double(minute) * 60), coordinate: tromso, calendar: calendar("Europe/Oslo"))
            XCTAssertEqual(winter.ink, .light, "Dec minute \(minute)")
            XCTAssertEqual(winter.moment, .night, "Dec minute \(minute)")
            let summer = SkyEngine.state(sky: .livingSky, at: date("2026-06-21T00:00:00+02:00").addingTimeInterval(Double(minute) * 60), coordinate: tromso, calendar: calendar("Europe/Oslo"))
            XCTAssertEqual(summer.ink, .dark, "Jun minute \(minute)")
        }
    }

    // Finding 6: text stays legible where the sky glow and Orbit halo light the background.
    func testTextStaysLegibleOverTheGlows() {
        let hanoi = GeoCoordinate(latitude: 21.03, longitude: 105.85)
        for sky in SkyID.allCases {
            for minute in stride(from: 0, to: 1440, by: 5) {
                let state = SkyEngine.state(sky: sky, at: date("2026-10-05T00:00:00+07:00").addingTimeInterval(Double(minute) * 60), coordinate: hanoi, calendar: calendar("Asia/Ho_Chi_Minh"))
                for stop in state.stops {
                    let lit = state.glow.composited(over: stop, opacity: SkyEngine.maximumGlowOpacity)
                    let secondary = state.inkColor.composited(over: lit, opacity: SkyEngine.secondaryOpacity)
                    XCTAssertGreaterThanOrEqual(SkyColor.contrast(state.inkColor, lit), 4.5, "\(sky) minute \(minute)")
                    XCTAssertGreaterThanOrEqual(SkyColor.contrast(secondary, lit), 4.5, "\(sky) minute \(minute) secondary")
                }
            }
        }
    }
}
