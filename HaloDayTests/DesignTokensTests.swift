import XCTest
import UIKit
@testable import HaloDay

final class DesignTokensTests: XCTestCase {
    func testBundledFrauncesRegistersAllThreeFaces() {
        HaloFonts.registerIfNeeded()
        HaloFonts.registerIfNeeded() // idempotent
        for name in [DS.Typeface.displayName, DS.Typeface.textName, DS.Typeface.italicName] {
            XCTAssertTrue(DS.Typeface.isAvailable(name), name)
        }
    }
    func testFrauncesCoversVietnamese() throws {
        HaloFonts.registerIfNeeded()
        let font = try XCTUnwrap(UIFont(name: DS.Typeface.displayName, size: 20))
        let sample = "Ngày của bạn, như một vòng sáng. Ẩm ướt, nỗ lực, Đường, ỡ ự ẳ"
        let characters = Array(sample.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        XCTAssertTrue(CTFontGetGlyphsForCharacters(font as CTFont, characters, &glyphs, characters.count))
    }
    func testSpacingScaleIsMonotonic() {
        let scale = [DS.Space.xs, DS.Space.s, DS.Space.m, DS.Space.l, DS.Space.xl, DS.Space.xxl, DS.Space.hero]
        XCTAssertEqual(scale, scale.sorted())
    }
}
