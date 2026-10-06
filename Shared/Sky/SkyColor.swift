import SwiftUI

/// A gamma-encoded sRGB color with the math the sky engine needs:
/// WCAG luminance/contrast, perceptual (OKLab) mixing and legibility adjustment.
struct SkyColor: Hashable, Sendable {
    var r: Double
    var g: Double
    var b: Double

    static let black = SkyColor(r: 0, g: 0, b: 0)
    static let white = SkyColor(r: 1, g: 1, b: 1)

    init(r: Double, g: Double, b: Double) {
        self.r = min(1, max(0, r)); self.g = min(1, max(0, g)); self.b = min(1, max(0, b))
    }
    init(hex: UInt32) {
        self.init(r: Double((hex >> 16) & 0xFF) / 255, g: Double((hex >> 8) & 0xFF) / 255, b: Double(hex & 0xFF) / 255)
    }
    init?(hexString: String) {
        let trimmed = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        guard trimmed.count == 6, let value = UInt32(trimmed, radix: 16) else { return nil }
        self.init(hex: value)
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b) }

    var luminance: Double {
        0.2126 * Self.linear(r) + 0.7152 * Self.linear(g) + 0.0722 * Self.linear(b)
    }
    static func contrast(_ a: SkyColor, _ b: SkyColor) -> Double {
        let x = a.luminance, y = b.luminance
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    /// Perceptual interpolation in OKLab. `t` is clamped to 0…1.
    func mixed(with other: SkyColor, _ t: Double) -> SkyColor {
        let t = min(1, max(0, t))
        if t == 0 { return self }
        if t == 1 { return other }
        let a = oklab, b = other.oklab
        return SkyColor(oklab: (a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t, a.2 + (b.2 - a.2) * t))
    }

    /// `self` drawn at `opacity` over `background`, blended in display (gamma) space like Core Animation.
    func composited(over background: SkyColor, opacity: Double) -> SkyColor {
        SkyColor(r: r * opacity + background.r * (1 - opacity),
                 g: g * opacity + background.g * (1 - opacity),
                 b: b * opacity + background.b * (1 - opacity))
    }

    /// The smallest sRGB step toward `target` that satisfies `predicate` (binary search; predicate must be monotone).
    func adjusted(towards target: SkyColor, until predicate: (SkyColor) -> Bool) -> SkyColor {
        if predicate(self) { return self }
        func step(_ t: Double) -> SkyColor {
            SkyColor(r: r + (target.r - r) * t, g: g + (target.g - g) * t, b: b + (target.b - b) * t)
        }
        var low = 0.0, high = 1.0
        for _ in 0..<30 {
            let middle = (low + high) / 2
            if predicate(step(middle)) { high = middle } else { low = middle }
        }
        return step(high)
    }

    // MARK: - Conversions

    private static func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    private static func encoded(_ c: Double) -> Double {
        let c = min(1, max(0, c))
        return c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055
    }
    private var oklab: (Double, Double, Double) {
        let lr = Self.linear(r), lg = Self.linear(g), lb = Self.linear(b)
        let l = cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb)
        let m = cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb)
        let s = cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb)
        return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)
    }
    private init(oklab: (Double, Double, Double)) {
        let (lightness, a, b) = oklab
        let l = pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3)
        let m = pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3)
        let s = pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3)
        self.init(r: Self.encoded(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
                  g: Self.encoded(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
                  b: Self.encoded(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s))
    }
}
