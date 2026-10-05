import SwiftUI

struct PaywallHero: View {
    var events: [CalendarEvent]
    var habits: [Habit]
    @Environment(\.haloReduceMotion) private var reduceMotion
    @State private var appeared = false
    private let themes = ["rubyGlass", "champagneDay", "midnightGold"]

    var body: some View {
        ZStack {
            ThemeBackground(breathing: true)
            ForEach(themes.indices, id: \.self) { index in
                PhonePreview(
                    preset: WidgetPreset(name: "Halo Day", themeId: themes[index]),
                    events: events, habits: habits
                )
                .scaleEffect(0.42)
                .rotationEffect(.degrees(reduceMotion ? 0 : appeared ? Double(index - 1) * 12 : 0))
                .offset(x: reduceMotion ? CGFloat(index - 1) * 56 : appeared ? CGFloat(index - 1) * 60 : 0,
                        y: appeared || reduceMotion ? 0 : 12)
                .opacity(appeared ? 1 : 0)
                .zIndex(index == 1 ? 3 : 1)
                .animation(Motion.resolve(Motion.stagger(index), reduceMotion: reduceMotion), value: appeared)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipped()
        .onAppear { appeared = true }
        .accessibilityHidden(true)
    }
}

#Preview("Fan · Pearl") {
    DesignPreview { PaywallHero(events: MockData.events(), habits: MockData.habits) }
}

#Preview("Fan · Gold Reduced Motion") {
    DesignPreview(themeID: "midnightGold", scheme: .dark, accessibility: true, reduceMotion: true) {
        PaywallHero(events: [], habits: [])
    }
}
