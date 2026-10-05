import SwiftUI

struct StudioPresetCarousel: View {
    var presets: [WidgetPreset]
    var events: [CalendarEvent]
    var habits: [Habit]
    var date: Date
    var onLoad: (WidgetPreset) -> Void
    var onActivate: (WidgetPreset) -> Void
    var onDelete: (WidgetPreset) -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your presets").haloFont(.displayM)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(presets) { item in
                        Button { onLoad(item) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                PhonePreview(preset: item, events: events, habits: habits, date: date)
                                    .scaleEffect(0.28).frame(width: 100, height: 128)
                                    .allowsHitTesting(false).accessibilityHidden(true)
                                Text(item.name).haloFont(.caption).lineLimit(2)
                            }
                            .padding(12).frame(width: 124)
                            .background(palette.surfaceSunken, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(PressableStyle())
                        .contextMenu {
                            Button("Load") { onLoad(item) }
                            Button("Make active") { onActivate(item) }
                            Button("Delete preset", role: .destructive) { onDelete(item) }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}

#Preview("Presets · Pearl") {
    DesignPreview {
        StudioPresetCarousel(presets: [WidgetPreset(name: "My Halo")], events: MockData.events(), habits: MockData.habits,
                             date: .now, onLoad: { _ in }, onActivate: { _ in }, onDelete: { _ in })
    }
}

#Preview("Presets · Gold Empty AX3") {
    DesignPreview(themeID: "midnightGold", scheme: .dark, accessibility: true, reduceMotion: true) {
        StudioPresetCarousel(presets: [], events: [], habits: [], date: .now,
                             onLoad: { _ in }, onActivate: { _ in }, onDelete: { _ in })
    }
}
