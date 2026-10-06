# Halo Day v2 · Phase 5 (Studio) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace v1 Widget Studio and Themes with the v2 Studio: Lock Screen "Setups" previewed as real Lock Screens over sky wallpapers, slot editing within iOS's real slot rules, sky wallpapers saved to Photos, and the "Halo today" share card.

**Architecture:** `LockSetup`/`LockSlot`/`WidgetKind` (Shared) replace `WidgetPreset`, migrated once from v1 presets. One set of Lock Screen accessory renderers (`AccessoryView`, Shared) is used by Studio now and by WidgetKit in Phase 6, so the preview is the widget. `WallpaperArt` and `ShareCardArt` are plain SwiftUI views rendered with `ImageRenderer`; `PhotoSaver` uses add-only Photos access. Studio is a `SkyScreen` with a paged carousel of `LockPreview`s and a slot editor sheet. Fixture mode never writes storage or Photos.

**Tech Stack:** SwiftUI, Photos (add-only), ImageRenderer, XCTest/XCUITest.

**Spec:** `docs/superpowers/specs/2026-10-06-halo-day-v2-redesign-design.md` (§1.4 constraints in SPEC v1, §4.5, §5 table, §6 items 5–6, §7 data changes)

## Global Constraints

Same as earlier phases. Lock Screen accessory content is drawn in a single ink (vibrant rendering); colour only in the "design" view. Slot rules: one inline line above the clock; the row below the clock holds 4 units (circular = 1, rectangular = 2).

## Review Focus

1. **v1 presets** migrate to setups once (no duplicates on relaunch), keeping the theme as a sky and the widget type as a slot — Task 1.
2. **Slot rules**: never more than 4 units; changing a slot's family re-validates; inline accepts only inline kinds — Task 1 tests.
3. **Photos denied**: saving a wallpaper surfaces a clear message with a Settings route; never crashes — Task 3.
4. **Free tier**: one setup, free skies only, two free wallpapers (Living Sky at dawn, Celestial); premium kinds/skies gate through the paywall without stacking sheets — Task 4.
5. **Share card privacy**: event titles hidden unless the person turns them on; sample data labelled — Task 3 test.

---

### Task 1: Lock setups, widget kinds and migration

**Files:** Create `Shared/Models/LockSetup.swift`; Modify `Shared/Storage/AppGroupStorage.swift`, `HaloDayApp/ViewModels/HaloModel.swift`, `HaloDayApp/Components/HaloViewActions.swift`, `HaloDayApp/App/HaloLaunchConfiguration.swift`; Test `HaloDayTests/LockSetupTests.swift`

**Interfaces — Produces:**
- `enum WidgetKind: String, CaseIterable, Codable, Sendable, Identifiable { orbit, nextUp, rhythm, rituals, countdown, month; title; symbol; families: [AccessoryFamily]; isPremium (rhythm, rituals); init(legacy: WidgetType) }` — legacy map: agenda→rhythm, week/mini/month→month, habit/ritual→rituals, focus→orbit, countdown→countdown.
- `enum AccessoryFamily: String, Codable, Sendable, CaseIterable { inline, circular, rectangular; units: Int (0, 1, 2) }`
- `struct LockSlot: Codable, Hashable, Sendable, Identifiable { id: UUID; kind: WidgetKind; family: AccessoryFamily }`
- `struct LockSetup: Codable, Hashable, Sendable, Identifiable { id, name, skyID: SkyID, inline: WidgetKind?, slots: [LockSlot], wallpaperShowsOrbit: Bool; static let rowUnits = 4; usedUnits; remainingUnits; isValid; isPremium; static func starter(name:sky:) ; init(legacy: WidgetPreset) }`
- `AppGroupStorage.setups: [LockSetup]` (reads `setups.v2`; if absent migrates `presets` and writes `setups.v2`), `activeSetupID: UUID?` (`activeSetup.v2`).
- `HaloModel.setups`, `HaloModel.activeSetupID`, `saveSetup(_:) -> Bool` (free: one setup and no premium content, else paywall), `removeSetup(_:)`, `activateSetup(_:)`; `HaloViewActions.saveSetup/removeSetup` (fixture-safe).

- [ ] **Step 1: failing tests**

<!-- file: HaloDayTests/LockSetupTests.swift -->
```swift
import XCTest
@testable import HaloDay

final class LockSetupTests: XCTestCase {
    func testStarterFitsTheLockScreenRow() {
        let setup = LockSetup.starter(name: "My Halo", sky: .livingSky)
        XCTAssertTrue(setup.isValid)
        XCTAssertEqual(setup.usedUnits, 4)
        XCTAssertEqual(setup.inline, .month)
        XCTAssertFalse(setup.isPremium)
    }
    func testRowNeverExceedsFourUnits() {
        var setup = LockSetup.starter(name: "x", sky: .livingSky)
        setup.slots.append(LockSlot(kind: .orbit, family: .circular))
        XCTAssertFalse(setup.isValid)
        setup.slots = [LockSlot(kind: .nextUp, family: .rectangular), LockSlot(kind: .rhythm, family: .rectangular)]
        XCTAssertTrue(setup.isValid)
        XCTAssertEqual(setup.remainingUnits, 0)
        setup.inline = .orbit
        XCTAssertFalse(setup.isValid, "orbit has no inline form")
        setup.inline = .nextUp
        setup.slots = [LockSlot(kind: .orbit, family: .rectangular)]
        XCTAssertFalse(setup.isValid, "orbit has no rectangular form")
    }
    func testLegacyPresetsBecomeSetups() {
        let preset = WidgetPreset(name: "Gold agenda", widgetType: .agenda, widgetFamily: .rectangular, themeId: "midnightGold")
        let setup = LockSetup(legacy: preset)
        XCTAssertEqual(setup.name, "Gold agenda")
        XCTAssertEqual(setup.skyID, .celestial)
        XCTAssertEqual(setup.slots.first?.kind, .rhythm)
        XCTAssertTrue(setup.isValid)
        XCTAssertEqual(WidgetKind(legacy: .habit), .rituals)
        XCTAssertEqual(WidgetKind(legacy: .week), .month)
        XCTAssertEqual(WidgetKind(legacy: .focus), .orbit)
    }
    func testPremiumContentIsDetected() {
        var setup = LockSetup.starter(name: "x", sky: .livingSky)
        XCTAssertFalse(setup.isPremium)
        setup.skyID = .aurora
        XCTAssertTrue(setup.isPremium)
        setup.skyID = .livingSky
        setup.slots = [LockSlot(kind: .rhythm, family: .rectangular)]
        XCTAssertTrue(setup.isPremium)
    }
    func testStorageMigratesPresetsOnce() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = AppGroupStorage(directory: directory)
        try storage.write([WidgetPreset(name: "A", widgetType: .month, widgetFamily: .rectangular, themeId: "pearlHalo")], key: "presets")
        XCTAssertEqual(storage.setups.map(\.name), ["A"])
        XCTAssertEqual(storage.setups.count, 1, "second read must not migrate again")
        var edited = storage.setups[0]; edited.name = "B"
        try storage.write([edited], key: "setups.v2")
        XCTAssertEqual(storage.setups.map(\.name), ["B"])
    }
}
```

- [ ] **Step 2:** run → FAIL.

- [ ] **Step 3: implement**

<!-- file: Shared/Models/LockSetup.swift -->
```swift
import Foundation

enum AccessoryFamily: String, Codable, Sendable, CaseIterable {
    case inline, circular, rectangular
    /// Width in the Lock Screen row below the clock (4 units).
    var units: Int {
        switch self {
        case .inline: 0
        case .circular: 1
        case .rectangular: 2
        }
    }
}

/// v2 widget kinds (spec §5).
enum WidgetKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case orbit, nextUp, rhythm, rituals, countdown, month
    var id: String { rawValue }
    var title: String {
        switch self {
        case .orbit: String(localized: "Orbit")
        case .nextUp: String(localized: "Next up")
        case .rhythm: String(localized: "Rhythm")
        case .rituals: String(localized: "Rituals")
        case .countdown: String(localized: "Countdown")
        case .month: String(localized: "Month")
        }
    }
    var symbol: String {
        switch self {
        case .orbit: "circle.dashed"
        case .nextUp: "arrow.right.circle"
        case .rhythm: "list.bullet"
        case .rituals: "circle.grid.cross"
        case .countdown: "hourglass"
        case .month: "calendar"
        }
    }
    /// Lock Screen families this kind can take.
    var families: [AccessoryFamily] {
        switch self {
        case .orbit, .rituals: [.circular]
        case .nextUp: [.rectangular, .inline]
        case .rhythm: [.rectangular]
        case .countdown: [.circular, .rectangular]
        case .month: [.inline, .rectangular]
        }
    }
    var isPremium: Bool { self == .rhythm || self == .rituals }
    init(legacy: WidgetType) {
        switch legacy {
        case .agenda: self = .rhythm
        case .week, .mini, .month: self = .month
        case .habit, .ritual: self = .rituals
        case .focus: self = .orbit
        case .countdown: self = .countdown
        }
    }
}

struct LockSlot: Codable, Hashable, Sendable, Identifiable {
    var id = UUID()
    var kind: WidgetKind
    var family: AccessoryFamily
}

/// One Lock Screen: a sky wallpaper, an optional inline line above the clock and up to four units of widgets below it.
struct LockSetup: Codable, Hashable, Sendable, Identifiable {
    static let rowUnits = 4
    var id = UUID()
    var name: String
    var skyID: SkyID = .livingSky
    var inline: WidgetKind? = .month
    var slots: [LockSlot] = []
    var wallpaperShowsOrbit = true

    var usedUnits: Int { slots.reduce(0) { $0 + $1.family.units } }
    var remainingUnits: Int { max(0, Self.rowUnits - usedUnits) }
    var isValid: Bool {
        usedUnits <= Self.rowUnits
            && slots.allSatisfy { $0.family != .inline && $0.kind.families.contains($0.family) }
            && (inline.map { $0.families.contains(.inline) } ?? true)
    }
    var isPremium: Bool { skyID.isPremium || slots.contains { $0.kind.isPremium } || inline?.isPremium == true }

    static func starter(name: String, sky: SkyID) -> LockSetup {
        LockSetup(name: name, skyID: sky, inline: .month,
                  slots: [LockSlot(kind: .nextUp, family: .rectangular), LockSlot(kind: .orbit, family: .circular), LockSlot(kind: .countdown, family: .circular)])
    }

    init(id: UUID = UUID(), name: String, skyID: SkyID = .livingSky, inline: WidgetKind? = .month, slots: [LockSlot] = [], wallpaperShowsOrbit: Bool = true) {
        self.id = id; self.name = name; self.skyID = skyID; self.inline = inline; self.slots = slots; self.wallpaperShowsOrbit = wallpaperShowsOrbit
    }

    /// A v1 preset becomes a setup with its theme as a sky and its widget as the first slot.
    init(legacy preset: WidgetPreset) {
        var settings = UserSettings()
        settings.selectedThemeId = preset.themeId
        let kind = WidgetKind(legacy: preset.widgetType)
        let family: AccessoryFamily = kind.families.contains(.rectangular) && preset.widgetFamily != .circular ? .rectangular : (kind.families.first { $0 != .inline } ?? .rectangular)
        self.init(id: preset.id, name: preset.name, skyID: settings.skyID, inline: .month, slots: [LockSlot(kind: kind, family: family)])
    }
}
```

In `AppGroupStorage` add:

```swift
    /// v2 setups; the first read after the update migrates v1 presets once.
    var setups: [LockSetup] {
        let stored: [LockSetup]? = read("setups.v2", fallback: nil)
        if let stored { return stored }
        let migrated = presets.map(LockSetup.init(legacy:))
        try? write(migrated, key: "setups.v2")
        return migrated
    }
    var activeSetupID: UUID? { UUID(uuidString: read("activeSetup.v2", fallback: "")) }
```

In `HaloModel`: `var setups: [LockSetup]` and `var activeSetupID: UUID?` loaded in `init` (and in `refresh`), plus:

```swift
    /// Saves (inserts or replaces) a setup. Free: one setup, free skies and kinds only.
    @discardableResult
    func saveSetup(_ setup: LockSetup) -> Bool {
        let isNew = !setups.contains { $0.id == setup.id }
        guard purchases.isPremium || (!setup.isPremium && (!isNew || setups.isEmpty)) else { showPaywall = true; return false }
        guard setup.isValid else { return false }
        if let index = setups.firstIndex(where: { $0.id == setup.id }) { setups[index] = setup } else { setups.append(setup) }
        if activeSetupID == nil { activeSetupID = setup.id }
        do {
            try storage.write(setups, key: "setups.v2")
            try storage.write(activeSetupID?.uuidString ?? "", key: "activeSetup.v2")
            WidgetCenter.shared.reloadAllTimelines()
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func removeSetup(_ id: UUID) {
        setups.removeAll { $0.id == id }
        if activeSetupID == id { activeSetupID = setups.first?.id }
        do {
            try storage.write(setups, key: "setups.v2")
            try storage.write(activeSetupID?.uuidString ?? "", key: "activeSetup.v2")
            WidgetCenter.shared.reloadAllTimelines()
        } catch { self.error = error.localizedDescription }
    }
    func activateSetup(_ id: UUID) {
        activeSetupID = id
        do { try storage.write(id.uuidString, key: "activeSetup.v2"); WidgetCenter.shared.reloadAllTimelines() }
        catch { self.error = error.localizedDescription }
    }
```

`HaloViewActions.saveSetup(_:model:fixture:) -> Bool` (fixture: same gating, mutate in memory only) and `removeSetup`. Fixture model: `model.setups = [.starter(name: String(localized: "My Halo"), sky: settings.skyID)]`, `activeSetupID = setups[0].id`.

- [ ] **Step 4:** run → 5 PASS; suite green. Commit `feat(studio): lock setups, widget kinds and v1 preset migration`.

---

### Task 2: Lock Screen accessory renderers

**Files:** Create `Shared/Widgets/WidgetData.swift`, `Shared/Widgets/AccessoryViews.swift`; Test `HaloDayTests/AccessoryViewTests.swift`

**Interfaces — Produces:** `struct WidgetData: Sendable { date, events, habits, focus, countdown, isSample; nextEvent; upcoming(limit:) ; monthProgress (dayOfMonth, daysInMonth, fraction, daysLeft) }`; `struct AccessoryView: View { kind, family, data, tint: Color? }` — `tint == nil` means vibrant (single ink via `.primary`), a colour gives the "design" rendering.

Designs (all fonts: titles `DS.Typeface.title`, numbers SF monospaced):
- **orbit · circular**: a 24 h ring (track 0.25 opacity), today's timed events as arcs, a dot at now; no text.
- **nextUp · rectangular**: caption "In 25 min" / "Now" / "Tomorrow"; title (1 line); "10:30 – 11:15". **inline**: "Design review · 10:30" (or "A clear day").
- **rhythm · rectangular**: up to 3 rows "10:30 Design review".
- **rituals · circular**: ring split into N segments, kept ones filled; centre "2/3".
- **countdown · circular**: days number + ring; **rectangular**: title + "12 days left". No countdown → "Add a countdown".
- **month · inline**: "Oct · 16% · 26 days left"; **rectangular**: month name, progress capsule, "Day 5 of 31".

- [ ] **Step 1: failing test** — render every `(kind, family)` in `kind.families` with `ImageRenderer` at 160×72 (rectangular), 64×64 (circular), 240×20 (inline) for vibrant and tinted, assert non-empty pixels; plus `WidgetData` unit checks (nextEvent picks the current event, upcoming excludes past/all-day, month progress for 5 Oct = day 5 of 31, 26 left).
- [ ] **Step 2:** implement; run → PASS. Localize new strings. Commit `feat(widgets): shared Lock Screen accessory renderers`.

---

### Task 3: Wallpaper, share card and Photos

**Files:** Create `Shared/Widgets/WallpaperArt.swift`, `HaloDayApp/Screens/Studio/ShareCardArt.swift`, `HaloDayApp/Services/ArtRenderer.swift`, `HaloDayApp/Services/PhotoSaver.swift`; Modify `HaloDayApp/Resources/Info.plist`, `InfoPlist.xcstrings`; Test `HaloDayTests/ArtRendererTests.swift`

**Interfaces — Produces:** `struct WallpaperArt: View { sky: SkyState; orbit: OrbitContent?; style: OrbitStyle }` (sky full-bleed; Orbit at 70 % width centred at 66 % height, 55 % opacity, so the clock area stays clean); `struct ShareCardArt: View { scene: DayScene; sky: SkyState; style: OrbitStyle; showTitles: Bool; events: [CalendarEvent]; isSample: Bool }` (date in Fraunces, Orbit, "2/3 rituals · 50′ focus · 4 events", up to four "10:30 Design review" lines only when `showTitles`, "Sample day" label when sample, "Halo Day" wordmark); `@MainActor enum ArtRenderer { wallpaper(_:) -> UIImage? (430×932 pt @3x = 1290×2796 px); shareCard(_:) -> UIImage? (360×640 pt @3x = 1080×1920 px) }`; `enum PhotoSaver { static func save(_ image: UIImage) async throws }` (add-only; `PhotoSaver.Failure.denied` with a localized message); `enum WallpaperMoment: CaseIterable { now, dawn (06:10), morning (09:30), golden (17:20), night (22:30) }`; `LockSetup.wallpaperIsFree(sky:moment:)` → Living Sky at dawn, or Celestial.

- [ ] **Step 1: failing tests** — wallpaper renders 1290×2796 with visible pixels; share card renders 1080×1920; `ShareCardArt` with `showTitles: false` contains no event title (assert via a pure helper `ShareCardArt.lines(events:showTitles:)` returning `[]`); free-wallpaper rule (dawn Living Sky and Celestial free, Aurora not, Living Sky at night not).
- [ ] **Step 2:** implement; Info.plist `NSPhotoLibraryAddUsageDescription` ("Halo Day saves the wallpapers you make to your photo library. It never reads your photos.") + vi ("Halo Day lưu hình nền bạn tạo vào thư viện ảnh. Ứng dụng không bao giờ đọc ảnh của bạn."). Run → PASS. Commit `feat(studio): sky wallpapers, share card and add-only Photos saving`.

---

### Task 4: Studio screen

**Files:** Create `HaloDayApp/Screens/Studio/StudioView.swift`, `LockPreview.swift`, `SlotEditorSheet.swift`; Modify `HaloDayApp/App/HaloDayApp.swift`; Delete `HaloDayApp/Screens/WidgetStudio/StudioView.swift`, `HaloDayApp/Screens/WidgetStudio/Components/{StudioControlTray,StudioPresetCarousel,StudioPreviewData,ThemeOrbPicker}.swift`, `HaloDayApp/Screens/Themes/` (keep `WidgetGuideView` + `GuideStepIllustration` for the guide sheet until Phase 7).

Behaviour and identifiers:
- `SkyScreen`; title "Studio" (display 34) and "Setup 1 of 2"; `+` (`studio-new-setup`; free with one setup → paywall).
- A paged carousel of `LockPreview` (one per setup, 9:19.5 card, ~540 pt tall): `WallpaperArt` for the setup's sky at the chosen moment; inline line above the clock (`studio-slot-inline`); the clock (`DS.Typeface.clock`); the slot row (`studio-slot-<index>`, `studio-slot-add` when units remain); ink = the wallpaper sky's ink when "As iOS shows it" (`studio-vibrant`, default on) else tinted with `OrbitPalette` colours. Each slot is an accessibility button labelled by its kind and family.
- Sky chips for the current setup (`studio-sky-<id>`, lock badge when premium and free) — premium while free → paywall; Moment chips (`studio-moment-<case>`) when the sky follows the sun; "Show Orbit on wallpaper" toggle.
- Actions: "Save wallpaper" (`studio-save-wallpaper`; free rule; fixture: no Photos, shows the success toast), `ShareLink` "Share today" (`studio-share`, with "Show event names" toggle `studio-share-titles` defaulting off), "Use on Lock Screen" (`studio-activate`, marks the active setup), "How to add widgets" (`studio-guide` → `model.showGuide`), "Delete setup" (`studio-delete`, confirmation, hidden when only one).
- `SlotEditorSheet(setupID:, slot: index | inline | add)`: kinds valid for the slot's family (`kind-<rawValue>`; premium kinds show a lock and, when free, an inline "See Premium" that dismisses first), a family switch when the kind supports both and units allow, and "Remove" (`slot-remove`). Every change goes through `HaloViewActions.saveSetup`.
- Toasts: success "Wallpaper saved to Photos." / errors from `PhotoSaver` via `model.error`.

- [ ] **Step 1: failing UI tests** — rewrite `testRecordStudioThemeAndTypeSwitching` (keeps its name for `record_ui_motion.sh`): fixture `studio`, tap `studio-slot-1` → `kind-countdown` → slot 1's label contains "Countdown"; tap `studio-sky-celestial` → selected; toggle `studio-vibrant`. Add `testStudioSavesWallpaperAndShares`: tap `studio-save-wallpaper` → "Wallpaper saved to Photos." appears; `studio-share` exists. Run → FAIL.
- [ ] **Step 2:** implement; delete v1 Studio/Themes; regenerate; build; unit suite green; localize.
- [ ] **Step 3:** UI tests PASS. Commit `feat(studio): v2 Studio with Lock Screen setups, slot editor, wallpapers and share card`.

---

### Task 5: Screenshots and regression

- [ ] Extend the matrix: per sky × language `studio` → `-1005-Studio` (6); per language the slot editor `-1005-Slots` (2); total 60; update `scripts/screenshots.sh` (regex adds `Studio|Slots`, expect 60). Review every capture (wallpaper legibility behind the clock and slots, vibrant vs design, carousel, chips, vi copy), fix, re-run. Full suite + SE build green. Commit `test(studio): Studio screenshots and journeys`.
