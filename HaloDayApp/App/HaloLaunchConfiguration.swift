import Foundation

struct HaloLaunchConfiguration {
    let isScreenshotMode: Bool
    let referenceDate: Date?
    let themeID: String?
    let colorScheme: String?
    let screen: String?
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let skyLab: Bool
    let skyLabMinutes: Int?
    let skyLabSky: String?
    let skyLabPlace: String?
    let skyLabSeason: String?

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
            if let time = value(after: "-UITestTime")?.split(separator: ":"), time.count == 2,
               let hour = Int(time[0]), let minute = Int(time[1]) {
                components.hour = hour
                components.minute = minute
            }
            referenceDate = components.date
        }
        return HaloLaunchConfiguration(
            isScreenshotMode: screenshotMode,
            referenceDate: referenceDate,
            themeID: value(after: "-UITestTheme"),
            colorScheme: value(after: "-UITestAppearance"),
            screen: value(after: "-UITestScreen"),
            reduceMotion: arguments.contains("-UITestReduceMotion"),
            reduceTransparency: arguments.contains("-UITestReduceTransparency"),
            skyLab: arguments.contains("-SkyLab"),
            skyLabMinutes: value(after: "-SkyLabMinutes").flatMap(Int.init),
            skyLabSky: value(after: "-SkyLabSky"),
            skyLabPlace: value(after: "-SkyLabPlace"),
            skyLabSeason: value(after: "-SkyLabSeason")
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
        // A month of varied sample days so the week strip and month grid have texture.
        model.events = (-35...35).flatMap { offset -> [CalendarEvent] in
            let day = Calendar.current.date(byAdding: .day, value: offset, to: referenceDate)!
            let all = MockData.events(on: day)
            if offset == 0 { return all }
            let weekend = Calendar.current.isDateInWeekend(day)
            return Array(all.prefix(weekend ? abs(offset) % 2 : 1 + abs(offset * 7) % 4))
        }
        model.countdowns = []
        if let sky = ProcessInfo.processInfo.arguments.firstIndex(of: "-UITestSky").flatMap({ ProcessInfo.processInfo.arguments.indices.contains($0 + 1) ? SkyID(rawValue: ProcessInfo.processInfo.arguments[$0 + 1]) : nil }) {
            model.settings.skyChoice = sky
        }
        model.presets = [WidgetPreset(name: "Pearl Agenda", themeId: settings.selectedThemeId)]
        model.selectedDate = referenceDate
        model.tab = switch screen {
        case "studio": .studio
        case "rituals", "you": .you
        default: .day
        }
        model.showFocus = screen == "focus"
        model.dayZoom = switch screen {
        case "calendar", "month": .month
        case "week": .week
        default: .day
        }
        model.showSettings = screen == "settings" || screen == "themes"
        model.showPaywall = screen == "paywall"
        return model
    }
}

private enum HaloFixtureData {
    static func habits(on date: Date) -> [Habit] {
        let day = Calendar.current.startOfDay(for: date)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: day)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: day)!
        return [
            Habit(id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!, title: String(localized: "Drink water"), icon: "drop", accentColor: ThemeRegistry.all[0].light.accent, completedDates: [day, yesterday, twoDaysAgo], timeOfDay: .morning),
            Habit(id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!, title: String(localized: "A page of journaling"), icon: "book.closed", accentColor: ThemeRegistry.all[1].light.accent, completedDates: [day, yesterday], timeOfDay: .evening),
            Habit(id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!, title: String(localized: "A little movement"), icon: "figure.walk", accentColor: ThemeRegistry.all[4].light.accent, completedDates: [yesterday], timeOfDay: .afternoon)
        ]
    }
}
