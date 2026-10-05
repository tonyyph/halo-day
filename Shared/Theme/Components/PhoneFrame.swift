import SwiftUI

struct PhoneFrame<Content: View>: View {
    var width: CGFloat = 226
    var height: CGFloat = 430
    var isExporting = false
    @ViewBuilder var content: Content
    @Environment(\.palette) private var palette

    var body: some View {
        content
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 36, style: .continuous).stroke(.black.opacity(0.85), lineWidth: 5)
                RoundedRectangle(cornerRadius: 38, style: .continuous).stroke(palette.hairline, lineWidth: 1).padding(-3)
            }
            .overlay(alignment: .top) {
                Capsule().fill(.black).frame(width: 72, height: 19).padding(.top, 12)
            }
            .shadow(color: palette.shadowTint.opacity(isExporting ? 0 : 0.14), radius: 28, y: 14)
            .accessibilityLabel("Widget preview")
    }
}

struct PhonePreview: View {
    var preset: WidgetPreset
    var events: [CalendarEvent]
    var habits: [Habit]
    var focus: FocusSession? = nil
    var countdown: Countdown? = nil
    var date: Date = .now
    var sample = true
    var isExporting = false
    var wallpaperScheme: ColorScheme?
    var onSelect: ((WidgetSize) -> Void)?
    var animateSlots = false
    var wallpaper: Image?
    var selectedSlot: Int?
    var selectionPulse = 0
    var onSlotSelect: ((Int, WidgetSize) -> Void)?
    @Environment(\.haloReferenceDate) private var referenceDate
    @Environment(\.colorScheme) private var currentScheme
    @Environment(\.haloReduceMotion) private var reduceMotion

    var body: some View {
        let theme = ThemeRegistry.theme(preset.themeId)
        let scheme = wallpaperScheme ?? (theme.darkOnly ? .dark : currentScheme)
        let colors = PaletteResolver.resolve(theme.darkOnly && scheme == .light ? ThemeRegistry.all[0] : theme, scheme: scheme)
        PhoneFrame(isExporting: isExporting) {
            Group {
                if preset.widgetFamily.isAccessory {
                    LockScreenMock(
                        preset: preset, events: events, habits: habits, focus: focus, countdown: countdown,
                        date: referenceDate ?? date, sample: sample, onSelect: onSelect, animateSlots: animateSlots,
                        wallpaper: wallpaper, selectedSlot: selectedSlot, selectionPulse: selectionPulse, onSlotSelect: onSlotSelect
                    )
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    HomeScreenMock(preset: preset, events: events, habits: habits, focus: focus,
                                   countdown: countdown, date: referenceDate ?? date, sample: sample, wallpaper: wallpaper)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
                }
            }
        }
        .environment(\.haloTheme, theme)
        .environment(\.palette, colors)
        .environment(\.colorScheme, scheme)
        .environment(\.dynamicTypeSize, .large)
        .animation(Motion.resolve(Motion.smooth, reduceMotion: reduceMotion), value: preset.widgetFamily.isAccessory)
        .animation(Motion.resolve(Motion.gentle, reduceMotion: reduceMotion), value: preset.themeId)
        .accessibilityElement(children: onSelect == nil && onSlotSelect == nil ? .combine : .contain)
    }
}

#Preview("Phone · Pearl") {
    DesignPreview { PhonePreview(preset: WidgetPreset(name: "My Halo"), events: MockData.events(), habits: MockData.habits) }
}

#Preview("Phone · Gold AX3") {
    DesignPreview(themeID: "midnightGold", scheme: .dark, accessibility: true, reduceMotion: true) {
        PhonePreview(preset: WidgetPreset(name: "My Halo", themeId: "midnightGold"), events: [], habits: [], isExporting: true)
    }
}
