import XCTest
@testable import HaloDay

/// Regressions found in the Phase 5 whole-branch review.
final class StudioReviewTests: XCTestCase {
    // I1: only premium content a free person adds is gated; migrated v1 content is grandfathered.
    func testFreeEditsOfAMigratedPremiumSetupAreAllowed() {
        let migrated = LockSetup(legacy: WidgetPreset(name: "Agenda", widgetType: .agenda, widgetFamily: .rectangular, themeId: "pearlHalo"))
        XCTAssertTrue(migrated.isPremium)
        var edited = migrated
        edited.skyID = .celestial
        edited.wallpaperShowsOrbit = false
        XCTAssertFalse(edited.addsPremium(over: migrated))
        var upgraded = migrated
        upgraded.slots.append(LockSlot(kind: .rituals, family: .circular))
        XCTAssertTrue(upgraded.addsPremium(over: migrated))
        var premiumSky = migrated
        premiumSky.skyID = .aurora
        XCTAssertTrue(premiumSky.addsPremium(over: migrated))
        XCTAssertTrue(LockSetup.starter(name: "x", sky: .mist).addsPremium(over: nil))
        XCTAssertFalse(LockSetup.starter(name: "x", sky: .livingSky).addsPremium(over: nil))
    }
    // I4: an unreadable setups file is never replaced by re-migrated v1 presets.
    func testCorruptSetupsAreNotOverwrittenByMigration() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = AppGroupStorage(directory: directory)
        try storage.write([WidgetPreset(name: "Old", widgetType: .month, widgetFamily: .rectangular, themeId: "pearlHalo")], key: "presets")
        let corrupt = Data(#"[{"id":"not-a-uuid","name":42}]"#.utf8)
        try corrupt.write(to: directory.appendingPathComponent("setups.v2.json"))
        XCTAssertEqual(storage.setups, [])
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("setups.v2.json")), corrupt)
    }
    // I4: setups written by a newer build with extra/missing optional fields still decode.
    func testSetupsDecodeWithMissingOptionalFields() throws {
        let json = #"[{"id":"00000000-0000-0000-0000-0000000000AA","name":"Lean","slots":[]}]"#
        let setups = try JSONDecoder().decode([LockSetup].self, from: Data(json.utf8))
        XCTAssertEqual(setups.first?.skyID, .livingSky)
        XCTAssertEqual(setups.first?.wallpaperShowsOrbit, true)
        XCTAssertEqual(setups.first?.inline, nil)
    }
}
