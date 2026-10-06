import SwiftUI

struct ThemeGalleryCard: View {
    var theme: HaloTheme
    var events: [CalendarEvent]
    var habits: [Habit]
    var premium = false
    var date: Date = .now
    @Environment(\.haloReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let colors = PaletteResolver.resolve(theme, scheme: scheme)
        let noMotion = reduceMotion
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                ThemeBackground()
                HaloWidgetContent(
                    date: date, type: .agenda, size: .medium, theme: theme,
                    events: events, habits: habits, focus: nil, countdown: nil
                )
                .padding(12)
                .frame(width: 240, height: 120, alignment: .topLeading)
                .background(colors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .scaleEffect(0.56)
                .frame(width: 140, height: 80)
                .scrollTransition(.interactive) { view, phase in
                    view.offset(y: noMotion ? 0 : phase.value * 12)
                }
            }
            .frame(height: 150)
            .clipped()

            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey(theme.name))
                    .haloFont(.displayS)
                    .fixedSize(horizontal: false, vertical: true)
                Text(LocalizedStringKey(theme.mood))
                    .haloFont(.caption)
                    .foregroundStyle(colors.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                Group {
                    if theme.isPremium { PremiumChip().opacity(premium ? 0 : 1) }
                    else { Label("Included", systemImage: "checkmark").haloFont(.caption) }
                }
                .frame(minHeight: 24, alignment: .leading)
            }
            .padding(14)
        }
        .foregroundStyle(colors.ink)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(colors.hairline, lineWidth: 0.5)
        }
        .haloTheme(theme)
    }
}

#Preview("Theme card · Ruby") {
    DesignPreview(themeID: "rubyGlass") {
        ThemeGalleryCard(theme: ThemeRegistry.theme("rubyGlass"), events: MockData.events(), habits: MockData.habits)
            .frame(width: 180)
    }
}

#Preview("Theme card · Champagne AX3") {
    DesignPreview(themeID: "champagneDay", accessibility: true, reduceMotion: true) {
        ThemeGalleryCard(theme: ThemeRegistry.theme("champagneDay"), events: [], habits: [])
    }
}
