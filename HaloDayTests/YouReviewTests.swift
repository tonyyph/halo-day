import XCTest
@testable import HaloDay

/// Regressions found in the Phase 4 whole-branch review.
@MainActor
final class YouReviewTests: XCTestCase {
    private final class StubLocation: LocationProviding {
        var result: Result<GeoCoordinate, any Error>
        var storedHapticsAtRequest: Bool?
        init(_ result: Result<GeoCoordinate, any Error>) { self.result = result }
        func approximateCoordinate() async throws -> GeoCoordinate {
            storedHapticsAtRequest = AppGroupStorage.shared.settings.haptics
            return try result.get()
        }
    }

    // I1: a denial is reported to the caller (shown inside Settings), not through the global alert that dismisses sheets.
    func testLocationDenialIsReturnedNotRaisedGlobally() async {
        let model = HaloModel()
        model.location = StubLocation(.failure(LocationService.LocationError.denied))
        let message = await model.useLocationForSky(true)
        XCTAssertNotNil(message)
        XCTAssertNil(model.error)
        XCTAssertNil(model.settings.approxCoordinate)
    }
    // I3: unsaved Settings edits are saved before the permission prompt can trigger a refresh.
    func testSettingsArePersistedBeforeAskingForLocation() async {
        let model = HaloModel()
        let stub = StubLocation(.success(GeoCoordinate(latitude: 21, longitude: 105.9)))
        model.location = stub
        let original = model.settings.haptics
        model.settings.haptics = !original
        _ = await model.useLocationForSky(true)
        XCTAssertEqual(stub.storedHapticsAtRequest, !original)
        XCTAssertEqual(model.settings.approxCoordinate?.latitude, 21)
        model.settings.haptics = original
        model.settings.approxCoordinate = nil
        model.persist()
    }
    // Minor 1 → Important: saving an edit keeps completions recorded meanwhile (e.g. by the widget).
    func testEditingARitualKeepsCompletionsRecordedMeanwhile() {
        let original = Habit(title: "Read", icon: "book", accentColor: "E0904A")
        var latest = original
        latest.completedDates = [Calendar.current.startOfDay(for: .now)]
        let merged = RitualEditorView.merged(latest: latest, original: original, title: "Read more", icon: "book.closed", color: "5B74D6", time: .evening)
        XCTAssertEqual(merged.completedDates, latest.completedDates)
        XCTAssertEqual(merged.title, "Read more")
        XCTAssertEqual(merged.timeOfDay, .evening)
        XCTAssertEqual(merged.id, original.id)
    }
}
