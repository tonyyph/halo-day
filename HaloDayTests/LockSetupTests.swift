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
