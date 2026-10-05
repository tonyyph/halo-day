import SwiftUI

struct HomeScreenMock: View {
    var preset: WidgetPreset
    var events: [CalendarEvent]
    var habits: [Habit]
    var focus: FocusSession?
    var countdown: Countdown?
    var date: Date
    var sample = false
    var wallpaper: Image?
    @Environment(\.haloTheme) private var theme
    @Environment(\.palette) private var palette

    var body: some View {
        let surface = palette.surface
        ZStack {
            ThemeBackground()
            if let wallpaper { wallpaper.resizable().scaledToFill().frame(width: 226, height: 430).clipped() }
            VStack(spacing: 20) {
                HaloWidgetContent(date: date, type: preset.widgetType, size: preset.widgetFamily, theme: theme,
                                  events: events, habits: habits, focus: focus, countdown: countdown, sample: sample)
                    .padding(12)
                    .frame(width: preset.widgetFamily == .small ? 110 : 190,
                           height: preset.widgetFamily == .large ? 220 : 120, alignment: .topLeading)
                    .background(surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.top, 54)
                Canvas { context, _ in
                    for index in 0..<12 {
                        let rect = CGRect(x: CGFloat(index % 4) * 48 + 10, y: CGFloat(index / 4) * 46, width: 31, height: 31)
                        context.fill(Path(roundedRect: rect, cornerRadius: 8), with: .color(surface.opacity(0.7)))
                    }
                }
                .frame(width: 190, height: 138).accessibilityHidden(true)
                Spacer(minLength: 0)
                Capsule().fill(surface.opacity(0.7)).frame(width: 190, height: 44).padding(.bottom, 24)
            }
        }
    }
}
