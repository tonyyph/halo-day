import XCTest
@testable import HaloDay

final class FocusModeTests: XCTestCase {
    func testDialAngleIsClockwiseFromTwelve() {
        let c = CGPoint(x: 100, y: 100)
        XCTAssertEqual(FocusDialMath.angle(of: CGPoint(x: 100, y: 0), center: c), 0, accuracy: 0.001)
        XCTAssertEqual(FocusDialMath.angle(of: CGPoint(x: 200, y: 100), center: c), 90, accuracy: 0.001)
        XCTAssertEqual(FocusDialMath.angle(of: CGPoint(x: 0, y: 100), center: c), 270, accuracy: 0.001)
    }
    func testDragAcrossTwelveCarriesTheLapAndSnaps() {
        let raw = FocusDialMath.advance(55, from: 350, to: 10)
        XCTAssertEqual(raw, 55 + 20.0 / 6, accuracy: 0.001)
        XCTAssertEqual(FocusDialMath.snapped(raw), 60)
        XCTAssertEqual(FocusDialMath.advance(6, from: 30, to: 0), 5)       // clamps at 5
        XCTAssertEqual(FocusDialMath.advance(239, from: 0, to: 90), 240)   // clamps at 240
        XCTAssertEqual(FocusDialMath.step(240, by: 5), 240)
        XCTAssertEqual(FocusDialMath.step(25, by: -5), 20)
    }
    func testFocusDuskIsAlwaysLightInkAndLegible() {
        let hanoi = GeoCoordinate(latitude: 21.03, longitude: 105.85)
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        let midnight = calendar.date(from: DateComponents(year: 2026, month: 10, day: 5))!
        for sky in SkyID.allCases {
            for minute in stride(from: 0, to: 1440, by: 30) {
                let dusk = SkyEngine.focusDusk(SkyEngine.state(sky: sky, at: midnight.addingTimeInterval(Double(minute) * 60), coordinate: hanoi, calendar: calendar))
                XCTAssertEqual(dusk.ink, .light, "\(sky) \(minute)")
                for stop in dusk.stops {
                    let lit = dusk.glow.composited(over: stop, opacity: SkyEngine.maximumGlowOpacity)
                    XCTAssertGreaterThanOrEqual(SkyColor.contrast(dusk.inkColor, lit), 4.5, "\(sky) \(minute)")
                    XCTAssertGreaterThanOrEqual(SkyColor.contrast(dusk.inkColor.composited(over: lit, opacity: SkyEngine.secondaryOpacity), lit), 4.5)
                }
            }
        }
    }
}
