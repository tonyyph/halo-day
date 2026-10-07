import XCTest
@testable import HaloDay

@MainActor
final class OnboardingTests: XCTestCase {
    private func pick(_ title: String, _ time: TimeOfDay) -> Habit { Habit(title: title, icon: "drop", accentColor: "E0904A", timeOfDay: time) }

    func testOnboardingReplacesUntouchedSampleRituals() {
        let model = HaloModel()
        model.habits = MockData.habits
        model.setups = []
        model.settings.hasCompletedOnboarding = false
        model.completeOnboarding(rituals: [pick("Water", .morning), pick("Read", .evening)], fixture: true)
        XCTAssertEqual(model.habits.map(\.title), ["Water", "Read"])
        XCTAssertEqual(model.setups.count, 1)
        XCTAssertFalse(model.setups[0].isPremium)
        XCTAssertNotNil(model.activeSetupID)
        XCTAssertTrue(model.settings.hasCompletedOnboarding)
    }
    func testSkippingRitualsKeepsTheSamplesInsteadOfAnEmptyDay() {
        let model = HaloModel()
        model.habits = MockData.habits
        model.completeOnboarding(rituals: [], fixture: true)
        XCTAssertEqual(model.habits.map(\.id), MockData.habits.map(\.id))
    }
    func testOnboardingKeepsRitualsSomeoneAlreadyHas() {
        let model = HaloModel()
        var mine = pick("Stretch", .morning)
        mine.completedDates = [Calendar.current.startOfDay(for: .now)]
        model.habits = [mine]
        model.completeOnboarding(rituals: [pick("Stretch", .morning), pick("Read", .evening)], fixture: true)
        XCTAssertEqual(model.habits.map(\.title), ["Stretch", "Read"])
        XCTAssertEqual(model.habits[0].completedDates, mine.completedDates)
    }
    func testOpeningThePaywallClearsAnEarlierPurchaseOutcome() {
        let model = HaloModel()
        model.purchases.message = "Your purchase is awaiting approval."
        model.showPaywall = true
        XCTAssertNil(model.purchases.message)
    }
}
