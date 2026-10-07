import AppIntents
import SwiftUI

/// Builds the wallpaper for a setup from stored data, for Studio and for the Shortcuts action alike.
@MainActor
enum AgendaWallpaperMaker {
    static func art(setup: LockSetup, agenda: AgendaWallpaper, now: Date, sky: SkyState, events: (Date) -> [CalendarEvent],
                    habits: [Habit], coordinate: GeoCoordinate, isSample: Bool, photo: UIImage?) -> AgendaWallpaperArt {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: now)
        let orbit = OrbitContent(
            layout: OrbitLayout(day: day, events: events(day), calendar: calendar),
            beads: DaySceneBuilder.beads(for: habits, on: day),
            nightSpans: OrbitGeometry.nightSpans(SolarCalculator.day(containing: day, coordinate: coordinate, calendar: calendar), calendar: calendar),
            nowHour: OrbitGeometry.hours(of: now, calendar: calendar),
            moonPhase: SolarCalculator.moonPhase(at: now))
        return AgendaWallpaperArt(agenda: agenda, data: AgendaBuilder.build(now: now, isSample: isSample, events: events),
                                  sky: sky, style: setup.skyID.orbitStyle, orbit: orbit, photo: photo)
    }

    /// The in-use setup's agenda wallpaper as it should look right now, read straight from storage and the calendar.
    static func current(now: Date = .now) -> UIImage? {
        let storage = AppGroupStorage.shared
        let settings = storage.settings
        let setups = storage.setups
        guard let setup = setups.first(where: { $0.id == storage.activeSetupID }) ?? setups.first else { return nil }
        let agenda = setup.agenda ?? AgendaWallpaper()
        let coordinate = settings.approxCoordinate ?? TimeZoneLocator.approximateCoordinate(for: .current, at: now)
        let calendar = Calendar.current
        let service = CalendarService()
        let month = calendar.dateInterval(of: .month, for: now)!
        let week = calendar.dateInterval(of: .weekOfYear, for: now)!
        let interval = DateInterval(start: min(month.start, week.start), end: max(month.end, week.end))
        var all = service.events(in: interval, calendarIDs: settings.enabledCalendarIDs)
        if !settings.includeAllDay { all.removeAll { $0.isAllDay } }
        let events: (Date) -> [CalendarEvent] = { date in
            let day = calendar.dateInterval(of: .day, for: date)!
            return all.filter { $0.startDate < day.end && $0.endDate > day.start }
        }
        // A Premium sky that lapsed falls back to the free one, as everywhere else.
        let skyID = setup.skyID.isPremium && !settings.isPremium ? SkyID.livingSky : setup.skyID
        let sky = SkyEngine.state(sky: skyID, at: now, coordinate: coordinate)
        let art = art(setup: setup, agenda: agenda, now: now, sky: sky, events: events, habits: storage.habits,
                      coordinate: coordinate, isSample: !service.isAuthorized, photo: agenda.usesPhoto ? WallpaperPhotoStore.load(setup.id) : nil)
        return ArtRenderer.agendaWallpaper(art)
    }
}

/// "Make Halo Wallpaper": returns today's agenda wallpaper, for an automation to pass to "Set Wallpaper Photo".
struct MakeHaloWallpaperIntent: AppIntent {
    static let title: LocalizedStringResource = "Make Halo Wallpaper"
    static let description = IntentDescription("Draws your agenda into your Halo wallpaper. Follow it with Set Wallpaper Photo in an automation to keep your Lock Screen current.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        guard let image = AgendaWallpaperMaker.current(), let data = image.jpegData(compressionQuality: 0.92) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return .result(value: IntentFile(data: data, filename: "Halo Wallpaper.jpg", type: .jpeg))
    }
}

struct HaloAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: MakeHaloWallpaperIntent(),
                    phrases: ["Make a \(.applicationName) wallpaper", "Update my \(.applicationName) wallpaper"],
                    shortTitle: "Halo Wallpaper",
                    systemImageName: "photo.on.rectangle")
    }
}
