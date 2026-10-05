import SwiftUI
import ImageIO

enum StudioWallpaper: String, CaseIterable, Identifiable {
    case light = "Light", dark = "Dark", photo = "Photo"
    var id: Self { self }
    var scheme: ColorScheme { self == .light ? .light : .dark }
}

enum StudioScenario: String, CaseIterable, Identifiable {
    case live = "Live", morning = "Morning", busy = "Busy", empty = "Empty", focus = "Focus"
    var id: Self { self }
}

struct StudioPreviewData {
    let date: Date
    let events: [CalendarEvent]
    let habits: [Habit]
    let focus: FocusSession?
    let sample: Bool

    init(scenario: StudioScenario, date: Date, events: [CalendarEvent], habits: [Habit], focus: FocusSession?, theme: HaloTheme, sample: Bool) {
        self.date = scenario == .morning ? Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: date)! : date
        self.habits = scenario == .empty ? [] : habits
        self.sample = scenario == .live ? sample : false
        switch scenario {
        case .live: self.events = events; self.focus = focus
        case .empty: self.events = []; self.focus = nil
        case .morning: self.events = MockData.events(on: self.date); self.focus = nil
        case .busy:
            let extra = [11, 14, 17].enumerated().map { index, hour in
                let start = Calendar.current.date(bySettingHour: hour, minute: 15, second: 0, of: date)!
                return CalendarEvent(id: "preview-busy-\(index)", title: String(localized: "Design review"), startDate: start,
                                     endDate: start.addingTimeInterval(2700), location: String(localized: "Studio B"),
                                     calendarName: String(localized: "Work"), accentColor: theme.accentColor, source: "sample")
            }
            self.events = (MockData.events(on: date) + extra).sorted { $0.startDate < $1.startDate }
            self.focus = nil
        case .focus:
            let start = Date.now
            self.events = MockData.events(on: date)
            self.focus = FocusSession(title: String(localized: "Deep work"), startDate: start,
                                      endDate: start.addingTimeInterval(3000), durationMinutes: 50, accentColor: theme.dark.accent)
        }
    }
}

struct StudioBitmap: @unchecked Sendable {
    let image: CGImage
    nonisolated static func decode(_ data: Data) -> StudioBitmap? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1024
              ] as CFDictionary) else { return nil }
        return StudioBitmap(image: image)
    }
}
