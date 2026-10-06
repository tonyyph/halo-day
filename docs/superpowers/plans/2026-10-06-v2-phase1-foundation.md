# Halo Day v2 · Phase 1 (Nền tảng) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the pure Sky/Orbit engines, the shared Orbit and Sky renderers, the v2 design tokens with bundled Fraunces, and a DEBUG "Sky Lab" screen that shows them at any time, place and sky.

**Architecture:** Everything reusable lives in `Shared/` (compiled into app and widget extension). Math is pure and unit-tested: `SolarCalculator` (NOAA), `TimeZoneLocator`, `SkyColor` (sRGB/OKLab/contrast), `SkyEngine` (keyframes → `SkyState` with enforced legibility), `OrbitGeometry`/`OrbitLayout` (angles, lanes, night spans, hit-testing). Views (`SkyBackground`, `OrbitCanvas`) only draw what the engines produce. v1 code is untouched in this phase; v2 types use new names (`DS`, `SkyID`, `OrbitCanvas`) so both coexist until later phases delete v1.

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI `Canvas`, XCTest, CoreText font registration, Python `fontTools` (build-time only), Ruby `xcodeproj` generator.

**Spec:** `docs/superpowers/specs/2026-10-06-halo-day-v2-redesign-design.md` (§2, §7, §9, §10 Phase 1)

## Global Constraints

- iOS deployment target 18.0; Swift 6.0 with `SWIFT_STRICT_CONCURRENCY = complete`.
- New Swift files: run `ruby scripts/generate_project.rb` after adding them (the checked-in project is generated).
- No hex colors in views; hex values only in `SkyKeyframes.swift` (and test fixtures).
- Every user-facing string is localized (en + vi) through `scripts/vi_translations.json` → `scripts/generate_localizations.rb` → `scripts/apply_vi_localization.rb`.
- No once-per-second timers; sky updates per minute.
- Primary text **and** secondary text (ink at `SkyEngine.secondaryOpacity`) must reach contrast ≥ 4.5:1 against every sky gradient stop at every minute.
- Fraunces is OFL: ship `OFL.txt` next to the fonts.
- Test command (used throughout): `xcodebuild -project HaloDay.xcodeproj -scheme HaloDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO test -only-testing:HaloDayTests 2>&1 | tail -25`

## Review Focus

1. **Polar latitudes** (Tromsø in December/June): no NaN, sky stays night/day, Orbit night span covers all or nothing — pinned in Task 2 and Task 5 tests.
2. **Ink flip at dawn/dusk:** the gradient passes through a luminance band where neither ink passes AA; the engine must adjust stops, never ship an illegible minute — pinned by the every-10-minutes contrast sweep in Task 4.
3. **Events crossing midnight / zero-length / all-day:** clipped with continuation flags, given a minimum visible span, and all-day excluded — pinned in Task 5.
4. **Crowded days (> 3 overlapping events):** extra events become "+n" overflow markers instead of drawing off-ring — pinned in Task 5.
5. **Fonts missing in a target** (widget extension bundle, or Vietnamese glyph gaps): fall back to the system serif rather than to Helvetica, and the build script refuses a font without full Vietnamese coverage — pinned in Task 7.

---

### Task 1: Sky color math

**Files:**
- Create: `Shared/Sky/SkyColor.swift`
- Test: `HaloDayTests/SkyColorTests.swift`

**Interfaces:**
- Produces: `struct SkyColor: Hashable, Sendable` with `init(r:g:b:)`, `init(hex: UInt32)`, `init?(hexString: String)`, `r/g/b: Double` (gamma-encoded 0…1), `luminance: Double`, `static func contrast(_:_:) -> Double`, `func mixed(with:_ t:) -> SkyColor` (OKLab), `func composited(over:opacity:) -> SkyColor` (sRGB alpha blend of `self` over background), `func adjusted(towards target: SkyColor, until predicate: (SkyColor) -> Bool) -> SkyColor`, `static let black, white`, `var color: Color`.

- [ ] **Step 1: Write the failing test**

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `ruby scripts/generate_project.rb && xcodebuild … -only-testing:HaloDayTests/SkyColorTests` (the global test command with this filter)
Expected: build FAIL — `cannot find 'SkyColor' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: the global test command filtered to `HaloDayTests/SkyColorTests`
Expected: 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Shared/Sky/SkyColor.swift HaloDayTests/SkyColorTests.swift HaloDay.xcodeproj
git commit -m "feat(sky): add SkyColor contrast and OKLab math"
```

---

### Task 2: Solar calculator

**Files:**
- Create: `Shared/Sky/SolarCalculator.swift`
- Test: `HaloDayTests/SolarCalculatorTests.swift`

**Interfaces:**
- Produces: `struct GeoCoordinate: Codable, Hashable, Sendable { latitude, longitude: Double }`; `enum SolarDay: Equatable, Sendable { case normal(sunrise: Date, sunset: Date), polarDay, polarNight }`; `enum SolarCalculator { static func sunAltitude(at: Date, coordinate: GeoCoordinate) -> Double` (degrees, geometric) `; static func day(containing: Date, coordinate: GeoCoordinate, calendar: Calendar) -> SolarDay` (sunrise/sunset use the −0.833° standard horizon) `; static func moonPhase(at: Date) -> Double` (0 new, 0.5 full, →1) `}`.

- [ ] **Step 1: Write the failing test**

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `ruby scripts/generate_project.rb` then the global test command filtered to `HaloDayTests/SolarCalculatorTests`
Expected: build FAIL — `cannot find 'GeoCoordinate' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

struct GeoCoordinate: Codable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double
}

enum SolarDay: Equatable, Sendable {
    case normal(sunrise: Date, sunset: Date)
    case polarDay
    case polarNight
}

/// NOAA solar position equations (accurate to about a minute between ±72° latitude).
enum SolarCalculator {
    static func sunAltitude(at date: Date, coordinate: GeoCoordinate) -> Double {
        let (declination, equationOfTime) = parameters(julianDay: julianDay(date))
        let seconds = date.timeIntervalSince1970
        let utcMinutes = (seconds - (seconds / 86400).rounded(.down) * 86400) / 60
        var trueSolar = (utcMinutes + equationOfTime + 4 * coordinate.longitude).truncatingRemainder(dividingBy: 1440)
        if trueSolar < 0 { trueSolar += 1440 }
        let hourAngle = trueSolar / 4 - 180
        let lat = radians(coordinate.latitude), dec = radians(declination)
        let cosZenith = sin(lat) * sin(dec) + cos(lat) * cos(dec) * cos(radians(hourAngle))
        return 90 - degrees(acos(min(1, max(-1, cosZenith))))
    }

    static func day(containing date: Date, coordinate: GeoCoordinate, calendar: Calendar) -> SolarDay {
        let start = calendar.startOfDay(for: date)
        let localNoon = start.addingTimeInterval(12 * 3600)
        let (declination, equationOfTime) = parameters(julianDay: julianDay(localNoon))
        let lat = radians(coordinate.latitude), dec = radians(declination)
        let cosHourAngle = cos(radians(90.833)) / (cos(lat) * cos(dec)) - tan(lat) * tan(dec)
        if cosHourAngle > 1 { return .polarNight }
        if cosHourAngle < -1 { return .polarDay }
        let halfDayMinutes = degrees(acos(cosHourAngle)) * 4
        let utcMidnight = (localNoon.timeIntervalSince1970 / 86400).rounded(.down) * 86400
        var noon = Date(timeIntervalSince1970: utcMidnight + (720 - 4 * coordinate.longitude - equationOfTime) * 60)
        let end = start.addingTimeInterval(86400)
        while noon < start { noon.addTimeInterval(86400) }
        while noon >= end { noon.addTimeInterval(-86400) }
        return .normal(sunrise: noon.addingTimeInterval(-halfDayMinutes * 60), sunset: noon.addingTimeInterval(halfDayMinutes * 60))
    }

    /// Mean synodic phase: 0 new, 0.5 full.
    static func moonPhase(at date: Date) -> Double {
        let cycles = (julianDay(date) - 2451550.26) / 29.530588853
        let phase = cycles - cycles.rounded(.down)
        return phase < 0 ? phase + 1 : phase
    }

    // MARK: - NOAA terms

    private static func julianDay(_ date: Date) -> Double { date.timeIntervalSince1970 / 86400 + 2440587.5 }
    private static func radians(_ value: Double) -> Double { value * .pi / 180 }
    private static func degrees(_ value: Double) -> Double { value * 180 / .pi }

    /// Declination (degrees) and equation of time (minutes).
    private static func parameters(julianDay: Double) -> (Double, Double) {
        let t = (julianDay - 2451545) / 36525
        var meanLongitude = (280.46646 + t * (36000.76983 + t * 0.0003032)).truncatingRemainder(dividingBy: 360)
        if meanLongitude < 0 { meanLongitude += 360 }
        let anomaly = radians(357.52911 + t * (35999.05029 - 0.0001537 * t))
        let eccentricity = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
        let center = sin(anomaly) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2 * anomaly) * (0.019993 - 0.000101 * t) + sin(3 * anomaly) * 0.000289
        let omega = radians(125.04 - 1934.136 * t)
        let apparentLongitude = radians(meanLongitude + center - 0.00569 - 0.00478 * sin(omega))
        let seconds = 21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))
        let obliquity = radians(23 + (26 + seconds / 60) / 60 + 0.00256 * cos(omega))
        let declination = degrees(asin(sin(obliquity) * sin(apparentLongitude)))
        let y = pow(tan(obliquity / 2), 2)
        let l0 = radians(meanLongitude)
        let equation = y * sin(2 * l0) - 2 * eccentricity * sin(anomaly)
            + 4 * eccentricity * y * sin(anomaly) * cos(2 * l0)
            - 0.5 * y * y * sin(4 * l0) - 1.25 * eccentricity * eccentricity * sin(2 * anomaly)
        return (declination, 4 * degrees(equation))
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: the global test command filtered to `HaloDayTests/SolarCalculatorTests`
Expected: 6 tests PASS. If a published-time assertion misses by more than 2 minutes, re-check the reference value against timeanddate.com before touching the algorithm; never widen the tolerance.

- [ ] **Step 5: Commit**

```bash
git add Shared/Sky/SolarCalculator.swift HaloDayTests/SolarCalculatorTests.swift HaloDay.xcodeproj
git commit -m "feat(sky): add NOAA solar calculator and moon phase"
```

---

### Task 3: Time-zone coordinate fallback

**Files:**
- Create: `Shared/Sky/TimeZoneLocator.swift`
- Test: `HaloDayTests/TimeZoneLocatorTests.swift`

**Interfaces:**
- Consumes: `GeoCoordinate` (Task 2).
- Produces: `enum TimeZoneLocator { static func approximateCoordinate(for timeZone: TimeZone, at date: Date = .now) -> GeoCoordinate }` — table lookup, else latitude 0 / longitude from UTC offset (yields roughly 6:00/18:00 sun).

- [ ] **Step 1: Write the failing test**

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `ruby scripts/generate_project.rb` then the global test command filtered to `HaloDayTests/TimeZoneLocatorTests`
Expected: build FAIL — `cannot find 'TimeZoneLocator' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

/// Coarse location used to place the sun when the person declines location access.
enum TimeZoneLocator {
    static func approximateCoordinate(for timeZone: TimeZone, at date: Date = .now) -> GeoCoordinate {
        if let city = cities[timeZone.identifier] { return GeoCoordinate(latitude: city.0, longitude: city.1) }
        return GeoCoordinate(latitude: 0, longitude: Double(timeZone.secondsFromGMT(for: date)) / 240)
    }

    private static let cities: [String: (Double, Double)] = [
        "Asia/Ho_Chi_Minh": (10.82, 106.63), "Asia/Saigon": (10.82, 106.63), "Asia/Bangkok": (13.75, 100.50),
        "Asia/Singapore": (1.35, 103.82), "Asia/Tokyo": (35.68, 139.69), "Asia/Seoul": (37.57, 126.98),
        "Asia/Shanghai": (31.23, 121.47), "Asia/Hong_Kong": (22.32, 114.17), "Asia/Taipei": (25.03, 121.56),
        "Asia/Manila": (14.60, 120.98), "Asia/Jakarta": (-6.21, 106.85), "Asia/Kolkata": (28.61, 77.21),
        "Asia/Calcutta": (28.61, 77.21), "Asia/Dubai": (25.20, 55.27), "Europe/London": (51.51, -0.13),
        "Europe/Paris": (48.86, 2.35), "Europe/Berlin": (52.52, 13.40), "Europe/Madrid": (40.42, -3.70),
        "Europe/Rome": (41.90, 12.50), "Europe/Amsterdam": (52.37, 4.90), "Europe/Moscow": (55.76, 37.62),
        "Europe/Oslo": (59.91, 10.75), "America/New_York": (40.71, -74.01), "America/Chicago": (41.88, -87.63),
        "America/Denver": (39.74, -104.99), "America/Los_Angeles": (34.05, -118.24), "America/Toronto": (43.65, -79.38),
        "America/Vancouver": (49.28, -123.12), "America/Mexico_City": (19.43, -99.13), "America/Sao_Paulo": (-23.55, -46.63),
        "Australia/Sydney": (-33.87, 151.21), "Australia/Melbourne": (-37.81, 144.96), "Pacific/Auckland": (-36.85, 174.76),
        "Africa/Cairo": (30.04, 31.24), "Africa/Johannesburg": (-26.20, 28.05)
    ]
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: the global test command filtered to `HaloDayTests/TimeZoneLocatorTests`
Expected: 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Shared/Sky/TimeZoneLocator.swift HaloDayTests/TimeZoneLocatorTests.swift HaloDay.xcodeproj
git commit -m "feat(sky): approximate sun location from the time zone"
```

---

### Task 4: Sky keyframes and engine

**Files:**
- Create: `Shared/Sky/SkyKeyframes.swift`, `Shared/Sky/SkyEngine.swift`
- Modify: `scripts/vi_translations.json`, `HaloDayApp/Resources/Localizable.xcstrings` (via scripts)
- Test: `HaloDayTests/SkyEngineTests.swift`

**Interfaces:**
- Consumes: `SkyColor` (Task 1), `GeoCoordinate`, `SolarCalculator` (Task 2).
- Produces:
  - `enum SkyID: String, CaseIterable, Codable, Sendable, Identifiable { livingSky, celestial, instrument, aurora, goldenHour, mist }` with `title: String`, `isPremium: Bool`, `orbitStyle: OrbitStyle`, `followsSun: Bool`.
  - `enum OrbitStyle: String, Sendable { glow, engraved, ink }`.
  - `enum SkyMoment: String, CaseIterable, Sendable { night, blueHour, dawn, morning, midday, afternoon, goldenHour, dusk }` with `title: String`.
  - `enum InkScheme: Sendable { light, dark }` (light = light ink on a dark sky).
  - `struct SkyKeyframe: Sendable { altitude: Double; top, mid, bottom, glow: SkyColor; stars: Double }`.
  - `struct SkyState: Equatable, Sendable { top, mid, bottom, glow: SkyColor; stars: Double; ink: InkScheme; inkColor: SkyColor; moment: SkyMoment; sunAltitude: Double; isRising: Bool; var isNight: Bool { sunAltitude < -6 }; var stops: [SkyColor] { [top, mid, bottom] } }`.
  - `enum SkyEngine { static let darkInk, lightInk: SkyColor; static let secondaryOpacity = 0.8; static let minimumContrast = 4.5; static func state(sky: SkyID, at date: Date, coordinate: GeoCoordinate, calendar: Calendar = .current) -> SkyState }`.

- [ ] **Step 1: Write the failing test**

```swift
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
        XCTAssertEqual(moment("05:35"), .dawn)
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `ruby scripts/generate_project.rb` then the global test command filtered to `HaloDayTests/SkyEngineTests`
Expected: build FAIL — `cannot find 'SkyEngine' in scope`.

- [ ] **Step 3: Write `SkyKeyframes.swift`**

```swift
import Foundation

enum OrbitStyle: String, Sendable { case glow, engraved, ink }

enum SkyID: String, CaseIterable, Codable, Sendable, Identifiable {
    case livingSky, celestial, instrument, aurora, goldenHour, mist
    var id: String { rawValue }
    var title: String {
        switch self {
        case .livingSky: String(localized: "Living Sky")
        case .celestial: String(localized: "Celestial")
        case .instrument: String(localized: "Instrument")
        case .aurora: String(localized: "Aurora")
        case .goldenHour: String(localized: "Golden Hour")
        case .mist: String(localized: "Mist")
        }
    }
    var isPremium: Bool { self != .livingSky && self != .celestial }
    var followsSun: Bool { self == .livingSky }
    var orbitStyle: OrbitStyle {
        switch self {
        case .instrument: .engraved
        case .mist: .ink
        default: .glow
        }
    }
}

struct SkyKeyframe: Sendable {
    var altitude: Double
    var top: SkyColor
    var mid: SkyColor
    var bottom: SkyColor
    var glow: SkyColor
    var stars: Double

    init(_ altitude: Double, _ top: UInt32, _ mid: UInt32, _ bottom: UInt32, glow: UInt32, stars: Double = 0) {
        self.altitude = altitude
        self.top = SkyColor(hex: top); self.mid = SkyColor(hex: mid); self.bottom = SkyColor(hex: bottom)
        self.glow = SkyColor(hex: glow); self.stars = stars
    }
}

/// The only place sky hex values live. Living Sky has separate rising (morning) and
/// setting (evening) tracks, each sorted by sun altitude in degrees.
enum SkyKeyframes {
    static let night = SkyKeyframe(-18, 0x0B0E22, 0x111633, 0x1A1D3A, glow: 0x8EA2FF, stars: 1)
    static let midday = SkyKeyframe(45, 0x6FAAE8, 0xB4D5F2, 0xEEF4F7, glow: 0xFFF4D6)

    static let rising: [SkyKeyframe] = [
        night,
        SkyKeyframe(-9, 0x1B2350, 0x3A3F78, 0x6C5A8E, glow: 0xC7A6FF, stars: 0.45),
        SkyKeyframe(-2, 0x8E97D0, 0xE0B2C0, 0xF6CDA9, glow: 0xFFC99A),
        SkyKeyframe(12, 0x8DB4EA, 0xC9D3EE, 0xF6E9DE, glow: 0xFFE2B0),
        midday
    ]
    static let setting: [SkyKeyframe] = [
        night,
        SkyKeyframe(-9, 0x1A1F4A, 0x352F6A, 0x5C3F70, glow: 0xB98CFF, stars: 0.5),
        SkyKeyframe(-3, 0x3B2F63, 0x6E4473, 0x9E5560, glow: 0xFF9A7A, stars: 0.15),
        SkyKeyframe(6, 0xE59A7C, 0xF2B482, 0xF8D7A6, glow: 0xFFB36B),
        SkyKeyframe(22, 0x86B0E0, 0xD2D8E6, 0xF5E6CF, glow: 0xFFE0A6),
        midday
    ]
    static func fixed(_ sky: SkyID) -> SkyKeyframe {
        switch sky {
        case .livingSky, .celestial: SkyKeyframe(0, 0x0A0B1C, 0x12142C, 0x1C1A36, glow: 0x9DB0FF, stars: 1)
        case .aurora: SkyKeyframe(0, 0x06141F, 0x0E2A33, 0x1B2B4A, glow: 0x5CFFC2, stars: 0.7)
        case .instrument: SkyKeyframe(0, 0xF7F1E5, 0xF2EBDD, 0xEAE1CF, glow: 0xE8C9A0)
        case .goldenHour: SkyKeyframe(0, 0xE8A06E, 0xF3BC86, 0xF8DDB0, glow: 0xFFB36B)
        case .mist: SkyKeyframe(0, 0xD9DCE0, 0xE4E6E8, 0xEEEFF0, glow: 0xFFFFFF)
        }
    }
    static let darkInk = SkyColor(hex: 0x161A2B)
    static let lightInk = SkyColor(hex: 0xFBF7F0)
}
```

- [ ] **Step 4: Write `SkyEngine.swift`**

```swift
import Foundation

enum SkyMoment: String, CaseIterable, Sendable {
    case night, blueHour, dawn, morning, midday, afternoon, goldenHour, dusk
    var title: String {
        switch self {
        case .night: String(localized: "Quiet night")
        case .blueHour: String(localized: "Blue hour")
        case .dawn: String(localized: "Dawn")
        case .morning: String(localized: "Clear morning")
        case .midday: String(localized: "Bright noon")
        case .afternoon: String(localized: "Soft afternoon")
        case .goldenHour: String(localized: "Golden hour")
        case .dusk: String(localized: "Dusk")
        }
    }
}

enum InkScheme: Sendable { case light, dark }

struct SkyState: Equatable, Sendable {
    var top: SkyColor
    var mid: SkyColor
    var bottom: SkyColor
    var glow: SkyColor
    var stars: Double
    var ink: InkScheme
    var inkColor: SkyColor
    var moment: SkyMoment
    var sunAltitude: Double
    var isRising: Bool
    var isNight: Bool { sunAltitude < -6 }
    var stops: [SkyColor] { [top, mid, bottom] }
}

enum SkyEngine {
    static let darkInk = SkyKeyframes.darkInk
    static let lightInk = SkyKeyframes.lightInk
    /// Secondary text is the ink at this opacity; legibility is enforced for it too.
    static let secondaryOpacity = 0.8
    static let minimumContrast = 4.5

    static func state(sky: SkyID, at date: Date, coordinate: GeoCoordinate, calendar: Calendar = .current) -> SkyState {
        let altitude = SolarCalculator.sunAltitude(at: date, coordinate: coordinate)
        let rising = SolarCalculator.sunAltitude(at: date.addingTimeInterval(300), coordinate: coordinate) >= altitude
        let frame = sky.followsSun ? interpolate(rising ? SkyKeyframes.rising : SkyKeyframes.setting, altitude: altitude) : SkyKeyframes.fixed(sky)
        let (ink, stops) = legible([frame.top, frame.mid, frame.bottom])
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60
        return SkyState(top: stops[0], mid: stops[1], bottom: stops[2], glow: frame.glow, stars: frame.stars,
                        ink: ink, inkColor: ink == .light ? lightInk : darkInk,
                        moment: moment(altitude: altitude, rising: rising, hour: hour),
                        sunAltitude: altitude, isRising: rising)
    }

    static func moment(altitude: Double, rising: Bool, hour: Double) -> SkyMoment {
        switch altitude {
        case ..<(-12): .night
        case ..<(-4): .blueHour
        case ..<2: rising ? .dawn : .dusk
        case ..<10: rising ? .dawn : .goldenHour
        default: hour < 11 ? .morning : hour < 14.5 ? .midday : .afternoon
        }
    }

    private static func interpolate(_ frames: [SkyKeyframe], altitude: Double) -> SkyKeyframe {
        guard let first = frames.first, let last = frames.last else { return SkyKeyframes.night }
        if altitude <= first.altitude { return first }
        if altitude >= last.altitude { return last }
        let upperIndex = frames.firstIndex { $0.altitude > altitude }!
        let lower = frames[upperIndex - 1], upper = frames[upperIndex]
        let t = (altitude - lower.altitude) / (upper.altitude - lower.altitude)
        var frame = lower
        frame.altitude = altitude
        frame.top = lower.top.mixed(with: upper.top, t)
        frame.mid = lower.mid.mixed(with: upper.mid, t)
        frame.bottom = lower.bottom.mixed(with: upper.bottom, t)
        frame.glow = lower.glow.mixed(with: upper.glow, t)
        frame.stars = lower.stars + (upper.stars - lower.stars) * t
        return frame
    }

    /// Chooses the ink needing the smaller correction, then nudges each stop just enough
    /// that primary and secondary ink both pass `minimumContrast`.
    private static func legible(_ stops: [SkyColor]) -> (InkScheme, [SkyColor]) {
        func passes(_ ink: SkyColor) -> (SkyColor) -> Bool {
            { stop in
                SkyColor.contrast(ink, stop) >= minimumContrast + 0.01
                    && SkyColor.contrast(ink.composited(over: stop, opacity: secondaryOpacity), stop) >= minimumContrast + 0.01
            }
        }
        let forLight = stops.map { $0.adjusted(towards: .black, until: passes(lightInk)) }
        let forDark = stops.map { $0.adjusted(towards: .white, until: passes(darkInk)) }
        func cost(_ adjusted: [SkyColor]) -> Double {
            zip(stops, adjusted).reduce(0) { $0 + abs($1.0.luminance - $1.1.luminance) }
        }
        return cost(forLight) <= cost(forDark) ? (.light, forLight) : (.dark, forDark)
    }
}
```

- [ ] **Step 5: Run tests**

Run: the global test command filtered to `HaloDayTests/SkyEngineTests`
Expected: 5 tests PASS. If `testMomentsFollowTheSunInHanoi` fails on one boundary time (e.g. 17:50 → `.goldenHour`), print the altitude at that time and move the test time deeper into the intended phase — the moment thresholds in the spec are authoritative, the sample times are not. If the continuity test fails, add an intermediate keyframe in `SkyKeyframes` rather than loosening the 0.02 bound.

- [ ] **Step 6: Localize the new strings**

Add to `scripts/vi_translations.json` (keep the file sorted as it is):

```json
"Living Sky": "Living Sky",
"Celestial": "Celestial",
"Instrument": "Instrument",
"Aurora": "Aurora",
"Golden Hour": "Golden Hour",
"Mist": "Mist",
"Quiet night": "Đêm yên",
"Blue hour": "Giờ xanh",
"Dawn": "Bình minh",
"Clear morning": "Sáng trong",
"Bright noon": "Trưa nắng",
"Soft afternoon": "Chiều êm",
"Golden hour": "Giờ vàng",
"Dusk": "Hoàng hôn"
```

Run: `ruby scripts/generate_localizations.rb && ruby scripts/apply_vi_localization.rb`
Expected: `Applied N Vietnamese translations.` with no "Unknown localization keys".

- [ ] **Step 7: Commit**

```bash
git add Shared/Sky HaloDayTests/SkyEngineTests.swift scripts/vi_translations.json HaloDayApp/Resources/Localizable.xcstrings HaloDay.xcodeproj
git commit -m "feat(sky): Living Sky keyframes and legibility-enforcing engine"
```

---

### Task 5: Orbit geometry and layout

**Files:**
- Create: `Shared/Orbit/OrbitGeometry.swift`
- Test: `HaloDayTests/OrbitGeometryTests.swift`

**Interfaces:**
- Consumes: `CalendarEvent` (`Shared/Models/Models.swift`), `SolarDay` (Task 2).
- Produces:
  - `enum OrbitGeometry { static func angle(forHour: Double) -> Double` (radians, y-down; noon top, midnight bottom, 06 left, 18 right) `; static func hour(forAngle: Double) -> Double` (0..<24) `; static func point(forHour: Double, radius: CGFloat, center: CGPoint) -> CGPoint; static func hour(at: CGPoint, center: CGPoint) -> Double; static func hours(of: Date, calendar: Calendar) -> Double; static func nightSpans(_ day: SolarDay, calendar: Calendar) -> [ClosedRange<Double>]; static func hitTest(_ point: CGPoint, metrics: OrbitMetrics, layout: OrbitLayout, beads: [OrbitBead], nowHour: Double?) -> OrbitHit? }`
  - `struct OrbitMetrics { size; center; radius (0.39·size); trackWidth (0.052·size); func laneRadius(_ lane: Int) -> CGFloat; beadRadius (radius − 0.085·size); focusRadius (radius − 0.05·size); hitTolerance = 22 }`
  - `struct OrbitArc: Identifiable, Hashable, Sendable { id: String; start, end: Double; lane: Int; colorHex: String; continuesBefore, continuesAfter: Bool }`
  - `struct OrbitOverflow: Hashable, Sendable { hour: Double; count: Int }`
  - `struct OrbitLayout: Sendable { arcs: [OrbitArc]; overflow: [OrbitOverflow]; init(day: Date, events: [CalendarEvent], calendar: Calendar = .current, maxLanes: Int = 3, minimumSpan: Double = 0.25) }`
  - `struct OrbitBead: Identifiable, Hashable, Sendable { id: UUID; hour: Double; isDone: Bool; colorHex: String }`
  - `enum OrbitHit: Equatable { case now, bead(UUID), arc(String) }`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import HaloDay

final class OrbitGeometryTests: XCTestCase {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!; return c }
    private var day: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 5))! }
    private func event(_ id: String, _ start: Double, _ end: Double, allDay: Bool = false) -> CalendarEvent {
        CalendarEvent(id: id, title: id, startDate: day.addingTimeInterval(start * 3600), endDate: day.addingTimeInterval(end * 3600),
                      calendarName: "Work", accentColor: "E2607D", isAllDay: allDay)
    }

    func testCardinalHoursSitWhereTheSunDoes() {
        let center = CGPoint(x: 100, y: 100)
        func p(_ h: Double) -> CGPoint { OrbitGeometry.point(forHour: h, radius: 50, center: center) }
        XCTAssertEqual(p(12).x, 100, accuracy: 0.001); XCTAssertEqual(p(12).y, 50, accuracy: 0.001)   // top
        XCTAssertEqual(p(0).y, 150, accuracy: 0.001)                                                  // bottom
        XCTAssertEqual(p(6).x, 50, accuracy: 0.001)                                                   // left
        XCTAssertEqual(p(18).x, 150, accuracy: 0.001)                                                 // right
    }
    func testHourRoundTripsThroughPoints() {
        let center = CGPoint(x: 0, y: 0)
        for hour in stride(from: 0.0, to: 24, by: 0.5) {
            XCTAssertEqual(OrbitGeometry.hour(at: OrbitGeometry.point(forHour: hour, radius: 80, center: center), center: center), hour, accuracy: 0.0001)
        }
    }
    func testOverlappingEventsTakeLanesAndExcessBecomesOverflow() {
        let layout = OrbitLayout(day: day, events: [
            event("a", 9, 11), event("b", 9.5, 10.5), event("c", 10, 12), event("d", 10.2, 10.4), event("e", 10.25, 10.75),
            event("f", 13, 14), event("all", 0, 24, allDay: true)
        ], calendar: calendar)
        XCTAssertEqual(layout.arcs.map(\.id), ["a", "b", "c", "f"])
        XCTAssertEqual(layout.arcs.map(\.lane), [0, 1, 2, 0])
        XCTAssertEqual(layout.overflow, [OrbitOverflow(hour: 10.2, count: 2)])
    }
    func testMidnightCrossingIsClippedAndFlaggedAndTinyEventsStayVisible() {
        let layout = OrbitLayout(day: day, events: [event("late", 23, 26), event("early", -2, 1), event("blip", 15, 15)], calendar: calendar)
        let byID = Dictionary(uniqueKeysWithValues: layout.arcs.map { ($0.id, $0) })
        XCTAssertEqual(byID["late"]?.end, 24); XCTAssertEqual(byID["late"]?.continuesAfter, true)
        XCTAssertEqual(byID["early"]?.start, 0); XCTAssertEqual(byID["early"]?.continuesBefore, true)
        XCTAssertEqual(byID["blip"]!.end - byID["blip"]!.start, 0.25, accuracy: 0.0001)
    }
    func testNightSpansWrapPastMidnightAndHandlePolarDays() {
        let sunrise = day.addingTimeInterval(5.75 * 3600), sunset = day.addingTimeInterval(17.6 * 3600)
        let spans = OrbitGeometry.nightSpans(.normal(sunrise: sunrise, sunset: sunset), calendar: calendar)
        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(spans[0].lowerBound, 0); XCTAssertEqual(spans[0].upperBound, 5.75, accuracy: 0.001)
        XCTAssertEqual(spans[1].lowerBound, 17.6, accuracy: 0.001); XCTAssertEqual(spans[1].upperBound, 24)
        XCTAssertEqual(OrbitGeometry.nightSpans(.polarNight, calendar: calendar), [0...24])
        XCTAssertEqual(OrbitGeometry.nightSpans(.polarDay, calendar: calendar), [])
    }
    func testHitTestingPrefersNowThenBeadsThenArcs() {
        let metrics = OrbitMetrics(size: 300)
        let layout = OrbitLayout(day: day, events: [event("review", 10.5, 11.25)], calendar: calendar)
        let bead = OrbitBead(id: UUID(), hour: 7, isDone: false, colorHex: "E0904A")
        func at(_ hour: Double, _ radius: CGFloat) -> CGPoint { OrbitGeometry.point(forHour: hour, radius: radius, center: metrics.center) }
        XCTAssertEqual(OrbitGeometry.hitTest(at(10.1, metrics.radius), metrics: metrics, layout: layout, beads: [bead], nowHour: 10.08), .now)
        XCTAssertEqual(OrbitGeometry.hitTest(at(7, metrics.beadRadius), metrics: metrics, layout: layout, beads: [bead], nowHour: 10.08), .bead(bead.id))
        XCTAssertEqual(OrbitGeometry.hitTest(at(10.9, metrics.radius), metrics: metrics, layout: layout, beads: [bead], nowHour: 10.08), .arc("review"))
        XCTAssertNil(OrbitGeometry.hitTest(metrics.center, metrics: metrics, layout: layout, beads: [bead], nowHour: 10.08))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `ruby scripts/generate_project.rb` then the global test command filtered to `HaloDayTests/OrbitGeometryTests`
Expected: build FAIL — `cannot find 'OrbitGeometry' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation
import CoreGraphics

struct OrbitArc: Identifiable, Hashable, Sendable {
    var id: String
    var start: Double
    var end: Double
    var lane: Int
    var colorHex: String
    var continuesBefore: Bool
    var continuesAfter: Bool
}

struct OrbitOverflow: Hashable, Sendable {
    var hour: Double
    var count: Int
}

struct OrbitBead: Identifiable, Hashable, Sendable {
    var id: UUID
    var hour: Double
    var isDone: Bool
    var colorHex: String
}

enum OrbitHit: Equatable { case now, bead(UUID), arc(String) }

struct OrbitMetrics {
    var size: CGFloat
    var center: CGPoint { CGPoint(x: size / 2, y: size / 2) }
    var radius: CGFloat { size * 0.39 }
    var trackWidth: CGFloat { size * 0.052 }
    var beadRadius: CGFloat { radius - size * 0.085 }
    var focusRadius: CGFloat { radius - size * 0.05 }
    var hitTolerance: CGFloat { 22 }
    func laneRadius(_ lane: Int) -> CGFloat { radius + CGFloat(lane) * trackWidth * 1.15 }
}

/// Events for one day, laid out on the 24-hour ring. All-day events are excluded;
/// overlapping events take outward lanes, and anything past `maxLanes` becomes an overflow marker.
struct OrbitLayout: Sendable {
    var arcs: [OrbitArc]
    var overflow: [OrbitOverflow]

    init(day: Date, events: [CalendarEvent], calendar: Calendar = .current, maxLanes: Int = 3, minimumSpan: Double = 0.25) {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let timed = events
            .filter { !$0.isAllDay && $0.startDate < dayEnd && $0.endDate > dayStart }
            .sorted { ($0.startDate, $0.endDate, $0.id) < ($1.startDate, $1.endDate, $1.id) }
        var laneEnds: [Double] = []
        var arcs: [OrbitArc] = []
        var overflow: [OrbitOverflow] = []
        for event in timed {
            let start = max(0, event.startDate.timeIntervalSince(dayStart) / 3600)
            let rawEnd = min(24, event.endDate.timeIntervalSince(dayStart) / 3600)
            let end = min(24, max(rawEnd, start + minimumSpan))
            if let lane = (0..<maxLanes).first(where: { $0 >= laneEnds.count || laneEnds[$0] <= start }) {
                if lane < laneEnds.count { laneEnds[lane] = end } else { laneEnds.append(end) }
                arcs.append(OrbitArc(id: event.id, start: start, end: end, lane: lane, colorHex: event.accentColor,
                                     continuesBefore: event.startDate < dayStart, continuesAfter: event.endDate > dayEnd))
            } else if let last = overflow.last, start - last.hour < 1 {
                overflow[overflow.count - 1].count += 1
            } else {
                overflow.append(OrbitOverflow(hour: start, count: 1))
            }
        }
        self.arcs = arcs
        self.overflow = overflow
    }
}

enum OrbitGeometry {
    static func angle(forHour hour: Double) -> Double { (180 + (hour - 6) * 15) * .pi / 180 }

    static func hour(forAngle angle: Double) -> Double {
        let hour = (angle * 180 / .pi - 180) / 15 + 6
        let wrapped = hour.truncatingRemainder(dividingBy: 24)
        return wrapped < 0 ? wrapped + 24 : wrapped
    }

    static func point(forHour hour: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        let a = angle(forHour: hour)
        return CGPoint(x: center.x + radius * cos(a), y: center.y + radius * sin(a))
    }

    static func hour(at point: CGPoint, center: CGPoint) -> Double {
        hour(forAngle: atan2(point.y - center.y, point.x - center.x))
    }

    static func hours(of date: Date, calendar: Calendar) -> Double {
        date.timeIntervalSince(calendar.startOfDay(for: date)) / 3600
    }

    static func nightSpans(_ day: SolarDay, calendar: Calendar) -> [ClosedRange<Double>] {
        switch day {
        case .polarDay: return []
        case .polarNight: return [0...24]
        case let .normal(sunrise, sunset):
            return [0...hours(of: sunrise, calendar: calendar), hours(of: sunset, calendar: calendar)...24]
        }
    }

    static func hitTest(_ point: CGPoint, metrics: OrbitMetrics, layout: OrbitLayout, beads: [OrbitBead], nowHour: Double?) -> OrbitHit? {
        func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
        if let nowHour, distance(point, self.point(forHour: nowHour, radius: metrics.radius, center: metrics.center)) <= metrics.hitTolerance {
            return .now
        }
        if let bead = beads
            .map({ ($0, distance(point, self.point(forHour: $0.hour, radius: metrics.beadRadius, center: metrics.center))) })
            .filter({ $0.1 <= metrics.hitTolerance })
            .min(by: { $0.1 < $1.1 })?.0 {
            return .bead(bead.id)
        }
        let radial = distance(point, metrics.center)
        let hour = self.hour(at: point, center: metrics.center)
        let padding = 0.2
        return layout.arcs.first { arc in
            abs(radial - metrics.laneRadius(arc.lane)) <= metrics.trackWidth / 2 + metrics.hitTolerance / 2
                && hour >= arc.start - padding && hour <= arc.end + padding
        }.map { .arc($0.id) }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: the global test command filtered to `HaloDayTests/OrbitGeometryTests`
Expected: 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Shared/Orbit/OrbitGeometry.swift HaloDayTests/OrbitGeometryTests.swift HaloDay.xcodeproj
git commit -m "feat(orbit): 24h ring geometry, lanes, night spans and hit-testing"
```

---

### Task 6: Fraunces fonts, design tokens and font registration

**Files:**
- Create: `scripts/build_fonts.py`, `Shared/Fonts/HaloFraunces-Display.ttf`, `Shared/Fonts/HaloFraunces-Text.ttf`, `Shared/Fonts/HaloFraunces-Italic.ttf`, `Shared/Fonts/OFL.txt`, `Shared/Design/DesignTokens.swift`
- Modify: `scripts/generate_project.rb` (bundle `Shared/Fonts/*.ttf` + `OFL.txt` into app and widgets), `HaloDayApp/App/HaloDayApp.swift` (register fonts in `init`), `HaloDayWidgets/LockScreenWidgets/HaloWidgets.swift` (register fonts in `HaloWidgetBundle.init`)
- Test: `HaloDayTests/DesignTokensTests.swift`

**Interfaces:**
- Produces: `enum HaloFonts { static func registerIfNeeded() }`; `enum DS { enum Space { xs=4, s=8, m=12, l=16, xl=24, xxl=32, hero=48 }; enum Radius { control=14, glass=22, sheet=32 }; enum Motion { standard, morph, inkFlip; static func resolve(_:reduceMotion:) -> Animation }; enum Typeface { displayName, textName, italicName; static func display(_ size: CGFloat, relativeTo: Font.TextStyle = .largeTitle) -> Font; static func title(_:relativeTo:) -> Font; static func moment(_:relativeTo:) -> Font; static func clock(_ size: CGFloat) -> Font; static func isAvailable(_ name: String) -> Bool } }`.

- [ ] **Step 1: Write the font build script**

`scripts/build_fonts.py`:

```python
#!/usr/bin/env python3
"""Builds the static Fraunces instances bundled with Halo Day.

Usage: python3 -m venv /tmp/halo-fonts && /tmp/halo-fonts/bin/pip install fonttools
       /tmp/halo-fonts/bin/python scripts/build_fonts.py
Downloads the OFL variable fonts from google/fonts, pins the axes, renames the
families so they cannot collide with an installed Fraunces, and refuses to write
a font that lacks any Vietnamese glyph.
"""
import io, pathlib, sys, urllib.request
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

BASE = "https://raw.githubusercontent.com/google/fonts/main/ofl/fraunces/"
OUT = pathlib.Path(__file__).resolve().parent.parent / "Shared" / "Fonts"
VIETNAMESE = ("ĂăÂâĐđÊêÔôƠơƯư"
    "ẠạẢảẤấẦầẨẩẪẫẬậẮắẰằẲẳẴẵẶặẸẹẺẻẼẽẾếỀềỂểỄễỆệỈỉỊịỌọỎỏỐốỒồỔổỖỗỘộỚớỜờỞởỠỡỢợỤụỦủỨứỪừỬửỮữỰựỲỳỴỵỶỷỸỹ"
    "ÀàÁáÃãÈèÉéÌìÍíĨĩÒòÓóÕõÙùÚúŨũÝý")
INSTANCES = [
    ("Fraunces[SOFT,WONK,opsz,wght].ttf", {"opsz": 72, "wght": 340, "SOFT": 100, "WONK": 0}, "Display", "Regular"),
    ("Fraunces[SOFT,WONK,opsz,wght].ttf", {"opsz": 24, "wght": 420, "SOFT": 50, "WONK": 0}, "Text", "Regular"),
    ("Fraunces-Italic[SOFT,WONK,opsz,wght].ttf", {"opsz": 24, "wght": 360, "SOFT": 100, "WONK": 0}, "Italic", "Italic"),
]

def fetch(name):
    url = BASE + urllib.request.quote(name)
    with urllib.request.urlopen(url) as response:
        return response.read()

def rename(font, flavour, style):
    family = f"Halo Fraunces {flavour}"
    postscript = f"HaloFraunces-{flavour}"
    table = font["name"]
    for name_id in (1, 2, 3, 4, 6, 16, 17, 21, 22, 25):
        table.removeNames(nameID=name_id)
    for name_id, value in ((1, family), (2, style), (3, f"{postscript};halo-day"), (4, f"{family} {style}"), (6, postscript)):
        table.setName(value, name_id, 3, 1, 0x409)
        table.setName(value, name_id, 1, 0, 0)

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    cache = {}
    for source, axes, flavour, style in INSTANCES:
        if source not in cache:
            cache[source] = fetch(source)
        font = instancer.instantiateVariableFont(TTFont(io.BytesIO(cache[source])), axes)
        missing = [c for c in VIETNAMESE if ord(c) not in font.getBestCmap()]
        if missing:
            sys.exit(f"{flavour}: missing Vietnamese glyphs {''.join(missing)} — use the New York fallback instead")
        rename(font, flavour, style)
        font.save(OUT / f"HaloFraunces-{flavour}.ttf")
        print("wrote", OUT / f"HaloFraunces-{flavour}.ttf")
    (OUT / "OFL.txt").write_bytes(fetch("OFL.txt"))

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Build the fonts**

Run:
```bash
python3 -m venv "$TMPDIR/halo-fonts" && "$TMPDIR/halo-fonts/bin/pip" install -q fonttools && "$TMPDIR/halo-fonts/bin/python" scripts/build_fonts.py && ls -la Shared/Fonts
```
Expected: three `wrote …HaloFraunces-*.ttf` lines and `OFL.txt` present. If the script exits with "missing Vietnamese glyphs", stop: set `DS.Typeface` to use the system serif (New York) only, skip Steps 3's font bundling, and note the fallback in the spec's §2.4.

- [ ] **Step 3: Bundle the fonts in both targets**

In `scripts/generate_project.rb`, right after the `Dir.glob(File.join(root, 'Shared', '**', '*.swift'))` block, add:

```ruby
Dir.glob(File.join(root, 'Shared', 'Fonts', '*.{ttf,txt}')).sort.each do |file|
  ref = shared.new_file(file.delete_prefix(File.join(root, 'Shared') + '/'))
  [app, widgets].each { |target| target.resources_build_phase.add_file_reference(ref) }
end
```

- [ ] **Step 4: Write the failing test**

`HaloDayTests/DesignTokensTests.swift`:

```swift
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
```

- [ ] **Step 5: Run test to verify it fails**

Run: `ruby scripts/generate_project.rb` then the global test command filtered to `HaloDayTests/DesignTokensTests`
Expected: build FAIL — `cannot find 'HaloFonts' in scope`.

- [ ] **Step 6: Write `Shared/Design/DesignTokens.swift`**

```swift
import SwiftUI
import CoreText
import UIKit

/// Registers the bundled Fraunces faces with CoreText for whichever bundle is running
/// (the app, or the widget extension). Safe to call repeatedly.
enum HaloFonts {
    private static let registered: Bool = {
        let bundles = [Bundle.main, Bundle(for: BundleToken.self)]
        for name in ["HaloFraunces-Display", "HaloFraunces-Text", "HaloFraunces-Italic"] {
            guard UIFont(name: name, size: 12) == nil,
                  let url = bundles.lazy.compactMap({ $0.url(forResource: name, withExtension: "ttf") }).first else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return true
    }()
    static func registerIfNeeded() { _ = registered }
    private final class BundleToken {}
}

/// Halo Day v2 design tokens. v1 `HaloTokens`/`HaloFont`/`Motion` stay until their screens are removed.
enum DS {
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let hero: CGFloat = 48
    }
    enum Radius {
        static let control: CGFloat = 14
        static let glass: CGFloat = 22
        static let sheet: CGFloat = 32
    }
    enum Motion {
        static let standard = Animation.spring(response: 0.5, dampingFraction: 0.85)
        static let morph = Animation.spring(response: 0.7, dampingFraction: 0.86)
        static let inkFlip = Animation.easeInOut(duration: 0.6)
        static func resolve(_ animation: Animation, reduceMotion: Bool) -> Animation {
            reduceMotion ? .easeInOut(duration: 0.2) : animation
        }
    }
    enum Typeface {
        static let displayName = "HaloFraunces-Display"
        static let textName = "HaloFraunces-Text"
        static let italicName = "HaloFraunces-Italic"

        static func isAvailable(_ name: String) -> Bool { UIFont(name: name, size: 12) != nil }

        /// Large editorial headings.
        static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
            custom(displayName, size, style, fallback: .system(size: size, weight: .regular, design: .serif))
        }
        /// Event titles and section headings.
        static func title(_ size: CGFloat, relativeTo style: Font.TextStyle = .title3) -> Font {
            custom(textName, size, style, fallback: .system(size: size, weight: .medium, design: .serif))
        }
        /// The italic moment name under the clock ("Golden hour").
        static func moment(_ size: CGFloat, relativeTo style: Font.TextStyle = .subheadline) -> Font {
            custom(italicName, size, style, fallback: .system(size: size, design: .serif).italic())
        }
        /// Clock numerals; sized by the Orbit, not by Dynamic Type.
        static func clock(_ size: CGFloat) -> Font {
            .system(size: size, weight: .ultraLight, design: .default).monospacedDigit()
        }
        private static func custom(_ name: String, _ size: CGFloat, _ style: Font.TextStyle, fallback: Font) -> Font {
            HaloFonts.registerIfNeeded()
            return isAvailable(name) ? .custom(name, size: size, relativeTo: style) : fallback
        }
    }
}
```

- [ ] **Step 7: Register at launch in both targets**

In `HaloDayApp/App/HaloDayApp.swift`, first line of `init()`:

```swift
        HaloFonts.registerIfNeeded()
```

In `HaloDayWidgets/LockScreenWidgets/HaloWidgets.swift`, inside `struct HaloWidgetBundle: WidgetBundle` before `var body`:

```swift
    init() { HaloFonts.registerIfNeeded() }
```

- [ ] **Step 8: Run tests**

Run: `ruby scripts/generate_project.rb` then the global test command filtered to `HaloDayTests/DesignTokensTests`
Expected: 3 tests PASS. Then build the widget extension too: `xcodebuild -project HaloDay.xcodeproj -scheme HaloDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3` → `** BUILD SUCCEEDED **`, and `find ~/Library/Developer/Xcode/DerivedData -path '*HaloDayWidgets.appex/HaloFraunces-Display.ttf' | head -1` prints a path.

- [ ] **Step 9: Commit**

```bash
git add scripts/build_fonts.py scripts/generate_project.rb Shared/Fonts Shared/Design HaloDayTests/DesignTokensTests.swift HaloDayApp/App/HaloDayApp.swift HaloDayWidgets/LockScreenWidgets/HaloWidgets.swift HaloDay.xcodeproj
git commit -m "feat(design): bundle Fraunces and add v2 design tokens"
```

---

### Task 7: Sky background and Orbit renderer

**Files:**
- Create: `Shared/Sky/SkyBackground.swift`, `Shared/Orbit/OrbitCanvas.swift`
- Test: `HaloDayTests/OrbitRenderTests.swift`

**Interfaces:**
- Consumes: `SkyState`, `SkyColor`, `OrbitStyle` (Task 4), `OrbitLayout`, `OrbitBead`, `OrbitMetrics`, `OrbitGeometry` (Task 5).
- Produces:
  - `struct SkyBackground: View { init(state: SkyState) }` — gradient + glow + seeded stars, ignores safe area.
  - `struct OrbitContent: Sendable { var layout: OrbitLayout; var beads: [OrbitBead] = []; var focusSpans: [ClosedRange<Double>] = []; var nightSpans: [ClosedRange<Double>] = []; var nowHour: Double?; var moonPhase: Double = 0.5 }`
  - `struct OrbitCanvas: View { init(content: OrbitContent, sky: SkyState, style: OrbitStyle, breathing: Bool = false) }` — square, draws at whatever size it is given.

- [ ] **Step 1: Write the failing test** (renders offscreen at three sizes and both inks; asserts non-empty pixels so a broken Canvas is caught)

```swift
import XCTest
import SwiftUI
@testable import HaloDay

@MainActor
final class OrbitRenderTests: XCTestCase {
    private func sky(_ id: SkyID, hour: Int) -> SkyState {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: hour))!
        return SkyEngine.state(sky: id, at: date, coordinate: GeoCoordinate(latitude: 21.03, longitude: 105.85), calendar: calendar)
    }
    private func content() -> OrbitContent {
        let day = Calendar.current.startOfDay(for: .now)
        return OrbitContent(layout: OrbitLayout(day: day, events: MockData.events(on: day)),
                            beads: [OrbitBead(id: UUID(), hour: 7, isDone: true, colorHex: "E0904A")],
                            focusSpans: [8...8.5], nightSpans: [0...5.8, 17.6...24], nowHour: 10.1)
    }
    func testOrbitRendersForEveryStyleAndSize() throws {
        for (id, hour) in [(SkyID.livingSky, 10), (.livingSky, 23), (.instrument, 10), (.mist, 10)] {
            for size in [44.0, 160.0, 320.0] {
                let renderer = ImageRenderer(content: OrbitCanvas(content: content(), sky: sky(id, hour: hour), style: id.orbitStyle).frame(width: size, height: size))
                renderer.scale = 2
                let image = try XCTUnwrap(renderer.cgImage, "\(id) \(size)")
                XCTAssertEqual(image.width, Int(size * 2))
                XCTAssertTrue(hasVisiblePixels(image), "\(id) \(size) rendered nothing")
            }
        }
    }
    func testSkyBackgroundRenders() throws {
        let renderer = ImageRenderer(content: SkyBackground(state: sky(.livingSky, hour: 18)).frame(width: 120, height: 240))
        XCTAssertTrue(hasVisiblePixels(try XCTUnwrap(renderer.cgImage)))
    }
    private func hasVisiblePixels(_ image: CGImage) -> Bool {
        let width = image.width, height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return stride(from: 3, to: data.count, by: 4).contains { data[$0] > 0 }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `ruby scripts/generate_project.rb` then the global test command filtered to `HaloDayTests/OrbitRenderTests`
Expected: build FAIL — `cannot find 'OrbitCanvas' in scope`.

- [ ] **Step 3: Write `Shared/Sky/SkyBackground.swift`**

```swift
import SwiftUI

/// Full-bleed sky: three-stop gradient, a soft glow where the light comes from, and fixed (seeded) stars.
struct SkyBackground: View {
    var state: SkyState

    var body: some View {
        ZStack {
            LinearGradient(stops: [
                .init(color: state.top.color, location: 0),
                .init(color: state.mid.color, location: 0.5),
                .init(color: state.bottom.color, location: 1)
            ], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [state.glow.color.opacity(state.isNight ? 0.18 : 0.35), .clear],
                           center: UnitPoint(x: 0.5, y: 0.28), startRadius: 0, endRadius: 360)
            if state.stars > 0.01 {
                Canvas { context, size in
                    var generator = SeededGenerator(seed: 7)
                    for _ in 0..<110 {
                        let point = CGPoint(x: .random(in: 0...size.width, using: &generator), y: .random(in: 0...(size.height * 0.75), using: &generator))
                        let radius = CGFloat.random(in: 0.3...1.1, using: &generator)
                        let alpha = Double.random(in: 0.2...0.85, using: &generator) * state.stars
                        context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                                     with: .color(.white.opacity(alpha)))
                    }
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Deterministic PRNG so stars don't jump between renders.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
```

- [ ] **Step 4: Write `Shared/Orbit/OrbitCanvas.swift`**

```swift
import SwiftUI

struct OrbitContent: Sendable {
    var layout: OrbitLayout
    var beads: [OrbitBead] = []
    var focusSpans: [ClosedRange<Double>] = []
    var nightSpans: [ClosedRange<Double>] = []
    var nowHour: Double?
    var moonPhase: Double = 0.5
}

/// The one Orbit renderer shared by the app, widgets, Live Activities, wallpapers and share cards.
struct OrbitCanvas: View {
    var content: OrbitContent
    var sky: SkyState
    var style: OrbitStyle
    var breathing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if breathing && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                canvas(pulse: 1 + 0.06 * sin(timeline.date.timeIntervalSinceReferenceDate * 2 * .pi / 4))
            }
        } else {
            canvas(pulse: 1)
        }
    }

    private func canvas(pulse: Double) -> some View {
        Canvas { context, size in
            let metrics = OrbitMetrics(size: min(size.width, size.height))
            draw(in: &context, metrics: metrics, pulse: pulse)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private var ink: Color { sky.inkColor.color }

    private func ring(_ metrics: OrbitMetrics, radius: CGFloat, from start: Double, to end: Double) -> Path {
        if end - start >= 24 {
            return Path(ellipseIn: CGRect(x: metrics.center.x - radius, y: metrics.center.y - radius, width: radius * 2, height: radius * 2))
        }
        return Path { path in
            path.addArc(center: metrics.center, radius: radius,
                        startAngle: .radians(OrbitGeometry.angle(forHour: start)),
                        endAngle: .radians(OrbitGeometry.angle(forHour: end)), clockwise: false)
        }
    }

    private func eventColor(_ hex: String) -> Color {
        let base = SkyColor(hexString: hex) ?? sky.glow
        return (style == .glow ? base.mixed(with: sky.glow, 0.12) : base.mixed(with: sky.inkColor, 0.15)).color
    }

    private func draw(in context: inout GraphicsContext, metrics: OrbitMetrics, pulse: Double) {
        let center = metrics.center, size = metrics.size

        // 1. Halo / instrument face
        switch style {
        case .glow:
            let haloRadius = size * 0.5
            context.fill(Path(ellipseIn: CGRect(x: center.x - haloRadius, y: center.y - haloRadius, width: haloRadius * 2, height: haloRadius * 2)),
                         with: .radialGradient(Gradient(colors: [sky.glow.color.opacity(0.4), sky.glow.color.opacity(0)]),
                                               center: center, startRadius: 0, endRadius: haloRadius))
        case .engraved:
            let outer = metrics.radius + size * 0.075
            context.stroke(Path(ellipseIn: CGRect(x: center.x - outer, y: center.y - outer, width: outer * 2, height: outer * 2)),
                           with: .color(ink.opacity(0.25)), lineWidth: max(0.5, size * 0.002))
            for hour in 0..<24 {
                let major = hour % 6 == 0
                let a = OrbitGeometry.point(forHour: Double(hour), radius: outer, center: center)
                let b = OrbitGeometry.point(forHour: Double(hour), radius: outer - size * (major ? 0.03 : 0.015), center: center)
                context.stroke(Path { $0.move(to: a); $0.addLine(to: b) }, with: .color(ink.opacity(major ? 0.5 : 0.25)), lineWidth: max(0.5, size * 0.003))
            }
        case .ink:
            break
        }

        // 2. Track and night
        let track = metrics.trackWidth * (style == .ink ? 0.45 : 1)
        context.stroke(ring(metrics, radius: metrics.radius, from: 0, to: 24), with: .color(ink.opacity(style == .ink ? 0.25 : 0.1)), lineWidth: track)
        for span in content.nightSpans where span.upperBound > span.lowerBound {
            context.stroke(ring(metrics, radius: metrics.radius, from: span.lowerBound, to: span.upperBound),
                           with: .color(.black.opacity(sky.ink == .light ? 0.3 : 0.1)), lineWidth: track)
        }
        if style != .engraved {
            for hour in [0.0, 6, 12, 18] {
                let a = OrbitGeometry.point(forHour: hour, radius: metrics.radius + size * 0.05, center: center)
                let b = OrbitGeometry.point(forHour: hour, radius: metrics.radius + size * 0.065, center: center)
                context.stroke(Path { $0.move(to: a); $0.addLine(to: b) }, with: .color(ink.opacity(0.35)), lineWidth: max(0.5, size * 0.003))
            }
        }

        // 3. Events
        let now = content.nowHour ?? 24
        for arc in content.layout.arcs {
            context.stroke(ring(metrics, radius: metrics.laneRadius(arc.lane), from: arc.start, to: arc.end),
                           with: .color(eventColor(arc.colorHex).opacity(arc.end < now ? 0.45 : 1)),
                           style: StrokeStyle(lineWidth: track, lineCap: .round))
        }
        for marker in content.layout.overflow {
            let p = OrbitGeometry.point(forHour: marker.hour, radius: metrics.laneRadius(3), center: center)
            context.draw(Text(verbatim: "+\(marker.count)").font(.system(size: max(7, size * 0.035), weight: .semibold)).foregroundStyle(ink.opacity(0.8)), at: p)
        }

        // 4. Focus sessions
        for span in content.focusSpans {
            context.stroke(ring(metrics, radius: metrics.focusRadius, from: span.lowerBound, to: span.upperBound),
                           with: .color(ink.opacity(0.55)), style: StrokeStyle(lineWidth: max(1, size * 0.012), lineCap: .round))
        }

        // 5. Ritual beads
        for bead in content.beads {
            let p = OrbitGeometry.point(forHour: bead.hour, radius: metrics.beadRadius, center: center)
            let r = size * 0.018
            let color = (SkyColor(hexString: bead.colorHex) ?? sky.glow).color
            let dot = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            if bead.isDone {
                var glow = context
                glow.addFilter(.blur(radius: r * 1.2))
                glow.fill(Path(ellipseIn: CGRect(x: p.x - r * 1.8, y: p.y - r * 1.8, width: r * 3.6, height: r * 3.6)), with: .color(color.opacity(0.5)))
                context.fill(dot, with: .color(color))
            } else {
                context.stroke(dot, with: .color(color), lineWidth: max(1, size * 0.005))
            }
        }

        // 6. Now: sun by day, moon by night
        guard let nowHour = content.nowHour else { return }
        let p = OrbitGeometry.point(forHour: nowHour, radius: metrics.radius, center: center)
        let core = size * 0.03
        if sky.isNight {
            let disc = Path(ellipseIn: CGRect(x: p.x - core, y: p.y - core, width: core * 2, height: core * 2))
            var glow = context
            glow.addFilter(.blur(radius: core))
            glow.fill(Path(ellipseIn: CGRect(x: p.x - core * 2, y: p.y - core * 2, width: core * 4, height: core * 4)), with: .color(sky.glow.color.opacity(0.45 * pulse)))
            context.fill(disc, with: .color(SkyEngine.lightInk.color))
            let lit = (1 - cos(2 * .pi * content.moonPhase)) / 2
            let offset = core * 2 * lit * (content.moonPhase < 0.5 ? -1 : 1)
            var shadow = context
            shadow.clip(to: disc)
            shadow.fill(Path(ellipseIn: CGRect(x: p.x - core + offset, y: p.y - core, width: core * 2, height: core * 2)), with: .color(sky.mid.color.opacity(0.92)))
        } else {
            let glowRadius = size * 0.075 * pulse
            var glow = context
            glow.addFilter(.blur(radius: glowRadius * 0.5))
            glow.fill(Path(ellipseIn: CGRect(x: p.x - glowRadius, y: p.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2)),
                      with: .color(sky.glow.mixed(with: .white, 0.3).color.opacity(0.9)))
            context.fill(Path(ellipseIn: CGRect(x: p.x - core, y: p.y - core, width: core * 2, height: core * 2)), with: .color(.white))
        }
    }
}
```

- [ ] **Step 5: Run tests**

Run: the global test command filtered to `HaloDayTests/OrbitRenderTests`
Expected: 2 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add Shared/Sky/SkyBackground.swift Shared/Orbit/OrbitCanvas.swift HaloDayTests/OrbitRenderTests.swift HaloDay.xcodeproj
git commit -m "feat(orbit): shared Orbit canvas renderer and sky background"
```

---

### Task 8: Sky Lab (DEBUG) and visual verification

**Files:**
- Create: `HaloDayApp/Screens/SkyLab/SkyLabView.swift`
- Modify: `HaloDayApp/App/HaloLaunchConfiguration.swift` (parse `-SkyLab`, `-SkyLabMinutes`, `-SkyLabSky`, `-SkyLabPlace`, `-SkyLabSeason`), `HaloDayApp/App/HaloDayApp.swift` (show Sky Lab instead of the app when requested, DEBUG only)
- Test: `HaloDayUITests/SkyLabUITests.swift`

**Interfaces:**
- Consumes: everything from Tasks 1–7.
- Produces: `struct SkyLabView: View { init(minutes: Int, sky: SkyID, place: SkyLabPlace, season: SkyLabSeason) }`, `enum SkyLabPlace: String, CaseIterable { hanoi, london, tromso, sydney }`, `enum SkyLabSeason: String, CaseIterable { march, june, october, december }`; accessibility identifiers `skylab-root`, `skylab-moment`, `skylab-slider`.

- [ ] **Step 1: Write the failing UI test**

```swift
import XCTest

final class SkyLabUITests: XCTestCase {
    @MainActor
    func testSkyLabAcrossTheDay() throws {
        let cases: [(minutes: Int, sky: String, language: String)] = [
            (370, "livingSky", "vi"), (605, "livingSky", "vi"), (1100, "livingSky", "vi"), (1350, "livingSky", "vi"),
            (605, "instrument", "en"), (605, "mist", "en"), (1350, "aurora", "en"), (1080, "goldenHour", "en")
        ]
        for item in cases {
            let app = XCUIApplication()
            app.launchArguments += ["-SkyLab", "-SkyLabMinutes", "\(item.minutes)", "-SkyLabSky", item.sky, "-SkyLabPlace", "hanoi",
                                    "-AppleLanguages", "(\(item.language))", "-AppleLocale", item.language == "vi" ? "vi_VN" : "en_US"]
            app.launch()
            XCTAssertTrue(app.descendants(matching: .any)["skylab-root"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.staticTexts["skylab-moment"].exists)
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "SkyLab-\(item.sky)-\(item.minutes)-\(item.language)"
            shot.lifetime = .keepAlways
            add(shot)
            app.terminate()
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `ruby scripts/generate_project.rb && xcodebuild -project HaloDay.xcodeproj -scheme HaloDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO test -only-testing:HaloDayUITests/SkyLabUITests 2>&1 | tail -15`
Expected: FAIL — `skylab-root` never appears (the app launches normally).

- [ ] **Step 3: Add launch arguments**

In `HaloLaunchConfiguration`, add stored properties after `reduceTransparency`:

```swift
    let skyLab: Bool
    let skyLabMinutes: Int?
    let skyLabSky: String?
    let skyLabPlace: String?
    let skyLabSeason: String?
```

and in the `HaloLaunchConfiguration(...)` initializer call in `current`, after `reduceTransparency:`:

```swift
            reduceTransparency: arguments.contains("-UITestReduceTransparency"),
            skyLab: arguments.contains("-SkyLab"),
            skyLabMinutes: value(after: "-SkyLabMinutes").flatMap(Int.init),
            skyLabSky: value(after: "-SkyLabSky"),
            skyLabPlace: value(after: "-SkyLabPlace"),
            skyLabSeason: value(after: "-SkyLabSeason")
```

- [ ] **Step 4: Route to Sky Lab**

In `HaloDayApp.body`, wrap the `WindowGroup` content:

```swift
        WindowGroup {
            #if DEBUG
            if launch.skyLab {
                SkyLabView(minutes: launch.skyLabMinutes ?? 605,
                           sky: launch.skyLabSky.flatMap(SkyID.init(rawValue:)) ?? .livingSky,
                           place: launch.skyLabPlace.flatMap(SkyLabPlace.init(rawValue:)) ?? .hanoi,
                           season: launch.skyLabSeason.flatMap(SkyLabSeason.init(rawValue:)) ?? .october)
            } else {
                app
            }
            #else
            app
            #endif
        }
```

and move the existing `ThemedRoot(...)…​.onOpenURL { model.route($0) }` chain into a computed property on `HaloDayApp`:

```swift
    private var app: some View {
        ThemedRoot(model: model, launch: launch)
            // …the existing .task / .onChange / .onReceive / .onOpenURL modifiers, unchanged…
    }
```

- [ ] **Step 5: Write `HaloDayApp/Screens/SkyLab/SkyLabView.swift`**

```swift
#if DEBUG
import SwiftUI

enum SkyLabPlace: String, CaseIterable, Identifiable {
    case hanoi, london, tromso, sydney
    var id: String { rawValue }
    var name: String {
        switch self { case .hanoi: "Hà Nội"; case .london: "London"; case .tromso: "Tromsø"; case .sydney: "Sydney" }
    }
    var coordinate: GeoCoordinate {
        switch self {
        case .hanoi: GeoCoordinate(latitude: 21.03, longitude: 105.85)
        case .london: GeoCoordinate(latitude: 51.51, longitude: -0.13)
        case .tromso: GeoCoordinate(latitude: 69.65, longitude: 18.96)
        case .sydney: GeoCoordinate(latitude: -33.87, longitude: 151.21)
        }
    }
    var timeZone: TimeZone {
        let identifier = switch self {
        case .hanoi: "Asia/Ho_Chi_Minh"; case .london: "Europe/London"; case .tromso: "Europe/Oslo"; case .sydney: "Australia/Sydney"
        }
        return TimeZone(identifier: identifier)!
    }
}

enum SkyLabSeason: String, CaseIterable, Identifiable {
    case march, june, october, december
    var id: String { rawValue }
    var components: (month: Int, day: Int) {
        switch self { case .march: (3, 20); case .june: (6, 21); case .october: (10, 5); case .december: (12, 21) }
    }
}

/// Developer screen for judging the sky and Orbit at any minute, place, season and sky.
struct SkyLabView: View {
    @State var minutes: Double
    @State var sky: SkyID
    @State var place: SkyLabPlace
    @State var season: SkyLabSeason

    init(minutes: Int, sky: SkyID, place: SkyLabPlace, season: SkyLabSeason) {
        _minutes = State(initialValue: Double(minutes)); _sky = State(initialValue: sky)
        _place = State(initialValue: place); _season = State(initialValue: season)
    }

    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = place.timeZone; return c }
    private var day: Date { calendar.date(from: DateComponents(year: 2026, month: season.components.month, day: season.components.day))! }
    private var date: Date { day.addingTimeInterval(minutes * 60) }
    private var state: SkyState { SkyEngine.state(sky: sky, at: date, coordinate: place.coordinate, calendar: calendar) }

    private var content: OrbitContent {
        let events: [CalendarEvent] = [(8.0, 8.75, "6F86D8"), (10.5, 11.25, "E2607D"), (12.0, 13.0, "5B9AD6"), (14.5, 15.0, "E3A050"), (17.0, 18.0, "4FAE86"), (19.5, 21.0, "9B6FD0")]
            .enumerated().map { index, item in
                CalendarEvent(id: "lab-\(index)", title: "Event \(index)", startDate: day.addingTimeInterval(item.0 * 3600),
                              endDate: day.addingTimeInterval(item.1 * 3600), calendarName: "Lab", accentColor: item.2)
            }
        let solar = SolarCalculator.day(containing: day, coordinate: place.coordinate, calendar: calendar)
        return OrbitContent(layout: OrbitLayout(day: day, events: events, calendar: calendar),
                            beads: [OrbitBead(id: UUID(), hour: 7, isDone: true, colorHex: "E0904A"),
                                    OrbitBead(id: UUID(), hour: 8.3, isDone: true, colorHex: "E0904A"),
                                    OrbitBead(id: UUID(), hour: 21, isDone: false, colorHex: "E0904A")],
                            focusSpans: [9...9.4],
                            nightSpans: OrbitGeometry.nightSpans(solar, calendar: calendar),
                            nowHour: minutes / 60,
                            moonPhase: SolarCalculator.moonPhase(at: date))
    }

    var body: some View {
        let state = state
        let ink = state.inkColor.color
        ZStack {
            SkyBackground(state: state)
            VStack(spacing: DS.Space.l) {
                VStack(spacing: DS.Space.xs) {
                    Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.current)))
                        .font(DS.Typeface.title(20))
                    Text(verbatim: "\(sky.title) · \(place.name) · \(Int(state.sunAltitude))°")
                        .font(.footnote).opacity(SkyEngine.secondaryOpacity)
                }
                .padding(.top, DS.Space.xl)
                ZStack {
                    OrbitCanvas(content: content, sky: state, style: sky.orbitStyle, breathing: true)
                    VStack(spacing: 2) {
                        Text(String(format: "%02d:%02d", Int(minutes) / 60, Int(minutes) % 60))
                            .font(DS.Typeface.clock(54))
                        Text(state.moment.title)
                            .font(DS.Typeface.moment(17))
                            .opacity(SkyEngine.secondaryOpacity)
                            .accessibilityIdentifier("skylab-moment")
                    }
                }
                .frame(width: 320, height: 320)
                Text(verbatim: "Ngày của bạn, như một vòng sáng. Đường, ỡ ự ẳ")
                    .font(DS.Typeface.display(30))
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
                VStack(spacing: DS.Space.m) {
                    Slider(value: $minutes, in: 0...1439, step: 5).accessibilityIdentifier("skylab-slider")
                    Picker(selection: $sky) { ForEach(SkyID.allCases) { Text($0.title).tag($0) } } label: { Text(verbatim: "sky") }.pickerStyle(.menu)
                    Picker(selection: $place) { ForEach(SkyLabPlace.allCases) { Text($0.name).tag($0) } } label: { Text(verbatim: "place") }.pickerStyle(.segmented)
                    Picker(selection: $season) { ForEach(SkyLabSeason.allCases) { Text($0.rawValue.capitalized).tag($0) } } label: { Text(verbatim: "season") }.pickerStyle(.segmented)
                }
                .padding(DS.Space.l)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.glass, style: .continuous))
                .environment(\.colorScheme, state.ink == .light ? .dark : .light)
            }
            .padding(.horizontal, DS.Space.l)
            .foregroundStyle(ink)
            .tint(ink)
        }
        .animation(DS.Motion.inkFlip, value: state.ink)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("skylab-root")
    }
}
#endif
```

- [ ] **Step 6: Run the UI test**

Run: `ruby scripts/generate_project.rb && xcodebuild -project HaloDay.xcodeproj -scheme HaloDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO test -only-testing:HaloDayUITests/SkyLabUITests -resultBundlePath "$TMPDIR/skylab.xcresult" 2>&1 | tail -15`
Expected: PASS.

- [ ] **Step 7: Export and review the screenshots**

Run:
```bash
rm -rf "$TMPDIR/skylab-shots" && xcrun xcresulttool export attachments --path "$TMPDIR/skylab.xcresult" --output-path "$TMPDIR/skylab-shots" && ls "$TMPDIR/skylab-shots"
```
Open every PNG and check against spec §2: the four Living Sky times read as four distinct moods (dawn, morning, golden/dusk, night with stars and a moon); text is crisp on every sky; the Orbit has its halo, night shading on the lower half, event arcs, beads and a glowing sun/moon at the right hour; Vietnamese diacritics render in Fraunces with no fallback glyphs. Fix any visual defect in `SkyKeyframes`/`OrbitCanvas` and re-run Steps 6–7 before committing. Copy the reviewed set to `docs/screenshots/v2/skylab/`.

- [ ] **Step 8: Full regression**

Run: `xcodebuild -project HaloDay.xcodeproj -scheme HaloDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO test 2>&1 | tail -25`
Expected: all unit tests and the existing UI tests pass (v1 screens are unchanged in this phase). Also `xcodebuild … -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' CODE_SIGNING_ALLOWED=NO build` → `** BUILD SUCCEEDED **` (iOS 18 floor).

- [ ] **Step 9: Commit**

```bash
git add HaloDayApp/Screens/SkyLab HaloDayApp/App HaloDayUITests/SkyLabUITests.swift docs/screenshots/v2/skylab HaloDay.xcodeproj
git commit -m "feat(skylab): DEBUG Sky Lab with time, place, season and sky controls"
```
