import SwiftUI
import WidgetKit

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
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .stroke(.black.opacity(0.85), lineWidth: 5)
                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .stroke(palette.hairline, lineWidth: 1)
                    .padding(-3)
            }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(.black)
                    .frame(width: 72, height: 19)
                    .padding(.top, 12)
            }
            .shadow(color: palette.shadowTint.opacity(isExporting ? 0 : 0.14), radius: 28, y: 14)
            .accessibilityLabel("Widget preview")
    }
}

struct LockScreenMock: View {
    var preset: WidgetPreset
    var events: [CalendarEvent]
    var habits: [Habit]
    var focus: FocusSession?
    var countdown: Countdown?
    var date: Date
    var sample = false
    var onSelect: ((WidgetSize) -> Void)?

    @Environment(\.haloTheme) private var theme
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            ThemeBackground()
            VStack(spacing: 12) {
                Text(date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(.system(size: 11, weight: .medium))
                    .padding(.top, 48)

                Text(date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute())
                    .font(.system(size: 54, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.8)

                slot(type: preset.widgetFamily == .inline ? preset.widgetType : .month, size: .inline)
                    .frame(height: 16)

                HStack(spacing: 7) {
                    slot(type: preset.widgetType, size: preset.widgetFamily == .circular ? .circular : .rectangular)
                        .frame(width: preset.widgetFamily == .circular ? 48 : 108, height: 58)
                    slot(type: .month, size: .circular)
                        .frame(width: 39, height: 39)
                    slot(type: .ritual, size: .circular)
                        .frame(width: 39, height: 39)
                }
                .frame(height: 64)

                Spacer()
                HStack {
                    quickAction("flashlight.off.fill")
                    Spacer()
                    quickAction("camera.fill")
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
                Capsule().fill(palette.ink.opacity(0.45)).frame(width: 68, height: 3)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 12)
        }
        .foregroundStyle(palette.ink)
    }

    private func slot(type: WidgetType, size: WidgetSize) -> some View {
        HaloWidgetContent(
            date: date, type: type, size: size, theme: theme,
            events: events, habits: habits, focus: focus,
            countdown: countdown, sample: sample
        )
        .font(.system(size: 10))
        .minimumScaleFactor(0.65)
        .contentShape(Rectangle())
        .onTapGesture { onSelect?(size) }
        .accessibilityLabel(Text(LocalizedStringKey(size.rawValue.capitalized)))
    }

    private func quickAction(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 12))
            .frame(width: 28, height: 28)
            .background(palette.ink.opacity(0.08), in: Circle())
            .accessibilityHidden(true)
    }
}

struct HomeScreenMock: View {
    var preset: WidgetPreset
    var events: [CalendarEvent]
    var habits: [Habit]
    var focus: FocusSession?
    var countdown: Countdown?
    var date: Date
    var sample = false
    @Environment(\.haloTheme) private var theme
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            ThemeBackground()
            VStack(spacing: 20) {
                HaloWidgetContent(
                    date: date, type: preset.widgetType, size: preset.widgetFamily,
                    theme: theme, events: events, habits: habits, focus: focus,
                    countdown: countdown, sample: sample
                )
                .padding(12)
                .frame(width: preset.widgetFamily == .small ? 100 : 190,
                       height: preset.widgetFamily == .large ? 220 : 115, alignment: .topLeading)
                .background(palette.surface, in: ContainerRelativeShape())
                .padding(.top, 54)

                Canvas { context, size in
                    for index in 0..<12 {
                        let x = CGFloat(index % 4) * 48 + 10
                        let y = CGFloat(index / 4) * 46
                        let rect = CGRect(x: x, y: y, width: 31, height: 31)
                        let path = Path(roundedRect: rect, cornerRadius: 8)
                        context.fill(path, with: .color(palette.surface.opacity(0.7)))
                    }
                }
                .frame(width: 190, height: 138)
                .accessibilityHidden(true)
                Spacer(minLength: 0)
                Capsule().fill(palette.surface.opacity(0.7)).frame(width: 190, height: 44)
                    .padding(.bottom, 24)
            }
        }
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

    var body: some View {
        PhoneFrame(isExporting: isExporting) {
            Group {
                if preset.widgetFamily.isAccessory {
                    LockScreenMock(
                        preset: preset, events: events, habits: habits, focus: focus,
                        countdown: countdown, date: date, sample: sample, onSelect: onSelect
                    )
                } else {
                    HomeScreenMock(
                        preset: preset, events: events, habits: habits, focus: focus,
                        countdown: countdown, date: date, sample: sample
                    )
                }
            }
        }
        .haloTheme(ThemeRegistry.theme(preset.themeId))
        .environment(\.colorScheme, wallpaperScheme ?? (ThemeRegistry.theme(preset.themeId).darkOnly ? .dark : .light))
        .accessibilityElement(children: onSelect == nil ? .combine : .contain)
    }
}

#Preview("Phone · Pearl") {
    DesignPreview {
        PhonePreview(preset: WidgetPreset(name: "My Halo"), events: MockData.events(), habits: MockData.habits)
    }
}

#Preview("Phone · Gold Dark AX3") {
    DesignPreview(themeID: "midnightGold", scheme: .dark, accessibility: true, reduceMotion: true) {
        PhonePreview(preset: WidgetPreset(name: "My Halo", themeId: "midnightGold"), events: [], habits: [])
    }
}
