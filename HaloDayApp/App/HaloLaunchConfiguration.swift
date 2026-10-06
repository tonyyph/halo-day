import Foundation

struct HaloLaunchConfiguration {
    let isScreenshotMode: Bool
    let referenceDate: Date?
    let themeID: String?
    let colorScheme: String?
    let screen: String?
    let reduceMotion: Bool
    let reduceTransparency: Bool

    static let current: HaloLaunchConfiguration = {
        let arguments = ProcessInfo.processInfo.arguments
        func value(after key: String) -> String? {
            guard let index = arguments.firstIndex(of: key), arguments.indices.contains(index + 1) else { return nil }
            return arguments[index + 1]
        }
        let screenshotMode = arguments.contains("-UITestScreenshotMode")
        var referenceDate: Date?
        if screenshotMode {
            var components = DateComponents()
            components.calendar = Calendar(identifier: .gregorian)
            components.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
            components.year = 2026
            components.month = 10
            components.day = 5
            components.hour = 10
            components.minute = 5
            referenceDate = components.date
        }
        return HaloLaunchConfiguration(
            isScreenshotMode: screenshotMode,
            referenceDate: referenceDate,
            themeID: value(after: "-UITestTheme"),
            colorScheme: value(after: "-UITestAppearance"),
            screen: value(after: "-UITestScreen"),
            reduceMotion: arguments.contains("-UITestReduceMotion"),
            reduceTransparency: arguments.contains("-UITestReduceTransparency")
        )
    }()

    @MainActor
    func makeModel() -> HaloModel {
        let model = HaloModel()
        guard isScreenshotMode, let referenceDate else { return model }

        var settings = model.settings
        settings.hasCompletedOnboarding = screen != "onboarding"
        settings.selectedThemeId = themeID ?? "pearlHalo"
        settings.firstName = "Alex"
        settings.calendarPermissionGranted = false
        settings.notificationPermissionGranted = false
        settings.isPremium = false
        model.settings = settings
        model.habits = HaloFixtureData.habits(on: referenceDate)
        model.events = MockData.events(on: referenceDate)
        model.presets = [WidgetPreset(name: "Pearl Agenda", themeId: settings.selectedThemeId)]
        model.selectedDate = referenceDate
        model.tab = switch screen {
        case "calendar": 1
        case "studio": 2
        case "rituals": 3
        case "focus": 4
        default: 0
        }
        model.showSettings = screen == "settings" || screen == "themes"
        model.showPaywall = screen == "paywall"
        UserDefaults.standard.removeObject(forKey: "halo.lastRitualCelebration")
        return model
    }
}

private enum HaloFixtureData {
    static func habits(on date: Date) -> [Habit] {
        let day = Calendar.current.startOfDay(for: date)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: day)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: day)!
        return [
            Habit(id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!, title: String(localized: "Drink water"), icon: "drop", accentColor: ThemeRegistry.all[0].light.accent, completedDates: [day, yesterday, twoDaysAgo]),
            Habit(id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!, title: String(localized: "A page of journaling"), icon: "book.closed", accentColor: ThemeRegistry.all[1].light.accent, completedDates: [day, yesterday]),
            Habit(id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!, title: String(localized: "A little movement"), icon: "figure.walk", accentColor: ThemeRegistry.all[4].light.accent, completedDates: [yesterday])
        ]
    }
}
