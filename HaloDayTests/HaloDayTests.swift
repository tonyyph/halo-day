import XCTest
@testable import HaloDay

final class HaloDayTests: XCTestCase {
    @MainActor func testLocalStoreKitCatalogMatchesProductIDs() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "HaloDay", withExtension: "storekit"))
        let data = try Data(contentsOf: url)
        let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let products = try XCTUnwrap(catalog["products"] as? [[String: Any]])
        let groups = try XCTUnwrap(catalog["subscriptionGroups"] as? [[String: Any]])
        let subscriptions = groups.flatMap { $0["subscriptions"] as? [[String: Any]] ?? [] }
        let ids = Set((products + subscriptions).compactMap { $0["productID"] as? String })
        XCTAssertEqual(ids, Set(PurchaseService.productIDs))
    }
    func testStreakIgnoresDuplicateCompletionsAndAllowsYesterday() {
        let day = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: day)!
        let prior = Calendar.current.date(byAdding: .day, value: -2, to: day)!
        var habit = Habit(title: "Read", icon: "book", accentColor: ThemeRegistry.all[0].accentColor, completedDates: [yesterday, yesterday, prior])
        XCTAssertEqual(habit.streak(asOf: day), 2)
        habit.toggle(on: day); XCTAssertEqual(habit.streak(asOf: day), 3)
        habit.toggle(on: day); XCTAssertFalse(habit.isCompleted(on: day))
    }
    func testStorageRoundTripAndIndependentDomains() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let storage = AppGroupStorage(directory: directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        try storage.write(MockData.habits, key: "habits")
        var settings = UserSettings(); settings.selectedThemeId = "rubyGlass"
        try storage.write(settings, key: "settings")
        try storage.toggleHabit(MockData.habits[0].id)
        XCTAssertTrue(storage.habits[0].isCompleted())
        XCTAssertEqual(storage.settings.selectedThemeId, "rubyGlass")
        XCTAssertEqual(storage.habits.count, 3)
    }
    func testFocusRemainingClampsAndPauseFreezes() {
        let now = Date()
        var session = FocusSession(title: "Focus", startDate: now, endDate: now.addingTimeInterval(60), durationMinutes: 1, accentColor: ThemeRegistry.all[0].accentColor)
        XCTAssertEqual(session.remaining(at: now.addingTimeInterval(120)), 0)
        session.pausedRemaining = 45
        XCTAssertEqual(session.remaining(at: now.addingTimeInterval(120)), 45)
    }
    func testEveryPaletteHasAccessibleTextContrast() {
        for theme in ThemeRegistry.all {
            for palette in [theme.light, theme.dark] {
                XCTAssertGreaterThanOrEqual(contrast(palette.ink, palette.bg), 7, theme.name)
                XCTAssertGreaterThanOrEqual(contrast(palette.accentInk, palette.bg), 4.5, theme.name)
                XCTAssertGreaterThanOrEqual(contrast(palette.accentInk, palette.surface), 4.5, theme.name)
                XCTAssertGreaterThanOrEqual(contrast(palette.accentOn, palette.accent), 4.5, theme.name)
            }
        }
    }
    private func contrast(_ a: String, _ b: String) -> Double {
        func luminance(_ hex: String) -> Double {
            let value = UInt64(hex, radix: 16)!
            let channels = [16, 8, 0].map { shift -> Double in
                let c = Double((value >> shift) & 255) / 255
                return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
        }
        let x = luminance(a), y = luminance(b)
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}
