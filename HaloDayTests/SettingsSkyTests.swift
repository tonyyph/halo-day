import XCTest
import CoreLocation
@testable import HaloDay

@MainActor
final class SettingsSkyTests: XCTestCase {
    func testV1SettingsDecodeWithoutSkyFields() throws {
        let json = #"{"selectedThemeId":"midnightGold","hasCompletedOnboarding":true,"calendarPermissionGranted":false,"notificationPermissionGranted":false,"isPremium":false,"firstName":"Linh","haptics":true,"dayStartHour":7,"dayEndHour":22,"eventReminderMinutes":10,"enabledCalendarIDs":[],"includeAllDay":true,"liveActivities":true}"#
        let settings = try JSONDecoder().decode(UserSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.firstName, "Linh")
        XCTAssertNil(settings.skyChoice)
        XCTAssertNil(settings.approxCoordinate)
        XCTAssertEqual(settings.skyID, .celestial)
    }
    func testExplicitSkyChoiceWinsOverLegacyTheme() {
        var settings = UserSettings()
        settings.selectedThemeId = "midnightGold"
        settings.skyChoice = .mist
        XCTAssertEqual(settings.skyID, .mist)
    }
    func testPremiumSkyAsksForPremiumWhenFree() {
        let model = HaloModel()
        model.purchases.isPremium = false
        model.settings.skyChoice = nil
        model.applySky(.aurora)
        XCTAssertTrue(model.showPaywall)
        XCTAssertNil(model.settings.skyChoice)
        model.showPaywall = false
        model.applySky(.celestial)
        XCTAssertEqual(model.settings.skyChoice, .celestial)
        XCTAssertFalse(model.showPaywall)
    }
    func testLocationIsRoundedToATenthOfADegree() {
        let coordinate = LocationService.rounded(CLLocationCoordinate2D(latitude: 21.02851, longitude: 105.85417))
        XCTAssertEqual(coordinate.latitude, 21.0, accuracy: 0.0001)
        XCTAssertEqual(coordinate.longitude, 105.9, accuracy: 0.0001)
    }
    func testSkyCoordinatePrefersTheSavedLocation() {
        let model = HaloModel()
        model.settings.approxCoordinate = GeoCoordinate(latitude: 64.1, longitude: -21.9)
        XCTAssertEqual(model.skyCoordinate.latitude, 64.1)
    }
    func testInfoPlistDeclaresPrivacyStringsAndLiveActivities() {
        let info = Bundle.main.infoDictionary ?? [:]
        XCTAssertNotNil(info["NSCalendarsFullAccessUsageDescription"])
        XCTAssertNotNil(info["NSLocationWhenInUseUsageDescription"])
        XCTAssertEqual(info["NSSupportsLiveActivities"] as? Bool, true)
    }
}
