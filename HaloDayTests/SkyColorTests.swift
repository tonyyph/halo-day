import XCTest
@testable import HaloDay

final class SkyColorTests: XCTestCase {
    func testHexParsingAndLuminance() {
        XCTAssertEqual(SkyColor(hex: 0xFFFFFF).luminance, 1, accuracy: 0.0001)
        XCTAssertEqual(SkyColor(hex: 0x000000).luminance, 0, accuracy: 0.0001)
        XCTAssertEqual(SkyColor(hexString: "#B0152F"), SkyColor(hex: 0xB0152F))
        XCTAssertEqual(SkyColor(hexString: "b0152f"), SkyColor(hex: 0xB0152F))
        XCTAssertNil(SkyColor(hexString: "nope"))
    }
    func testContrastMatchesWCAG() {
        XCTAssertEqual(SkyColor.contrast(.black, .white), 21, accuracy: 0.01)
        XCTAssertEqual(SkyColor.contrast(SkyColor(hex: 0x777777), .white), 4.48, accuracy: 0.02)
    }
    func testOKLabMixEndpointsAndMidpoint() {
        let a = SkyColor(hex: 0x1B2350), b = SkyColor(hex: 0xF6CDA9)
        XCTAssertEqual(a.mixed(with: b, 0), a)
        XCTAssertEqual(b.mixed(with: a, 0), b)
        let mid = a.mixed(with: b, 0.5)
        XCTAssertGreaterThan(mid.luminance, a.luminance)
        XCTAssertLessThan(mid.luminance, b.luminance)
    }
    func testCompositeAndAdjust() {
        let grey = SkyColor(hex: 0x808080)
        XCTAssertEqual(SkyColor.white.composited(over: .black, opacity: 1), .white)
        XCTAssertEqual(SkyColor.white.composited(over: .black, opacity: 0).luminance, 0, accuracy: 0.0001)
        let darker = grey.adjusted(towards: .black) { $0.luminance <= 0.1 }
        XCTAssertLessThanOrEqual(darker.luminance, 0.1)
        XCTAssertGreaterThan(darker.luminance, 0.09)
        XCTAssertEqual(grey.adjusted(towards: .black) { _ in true }, grey)
    }
}
