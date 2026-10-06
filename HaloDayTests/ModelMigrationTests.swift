import XCTest
@testable import HaloDay

final class ModelMigrationTests: XCTestCase {
    func testLegacyHabitDecodesAsAnytime() throws {
        let json = #"[{"id":"00000000-0000-0000-0000-000000000009","title":"Read","icon":"book","accentColor":"B0152F","completedDates":[],"targetFrequency":1}]"#
        let habits = try JSONDecoder().decode([Habit].self, from: Data(json.utf8))
        XCTAssertEqual(habits.first?.timeOfDay, .anytime)
        XCTAssertEqual(habits.first?.title, "Read")
    }
    func testHabitTimeOfDayRoundTrips() throws {
        let habit = Habit(title: "Run", icon: "figure.run", accentColor: "0F6B4C", timeOfDay: .morning)
        XCTAssertEqual(try JSONDecoder().decode(Habit.self, from: JSONEncoder().encode(habit)), habit)
    }
    func testLegacyThemesMapToSkies() {
        var settings = UserSettings()
        let expected: [(String, SkyID)] = [("pearlHalo", .livingSky), ("rubyGlass", .livingSky), ("graphiteFocus", .celestial),
                                           ("midnightGold", .celestial), ("champagneDay", .goldenHour), ("ivoryMinimal", .instrument),
                                           ("emeraldRitual", .livingSky), ("roseAtelier", .livingSky)]
        for (theme, sky) in expected { settings.selectedThemeId = theme; XCTAssertEqual(settings.skyID, sky, theme) }
    }
    func testAnchorsSitInTheirPartOfTheDay() {
        XCTAssertEqual(TimeOfDay.allCases.map(\.anchorHour), [7.5, 13.5, 20, 12])
    }
}
