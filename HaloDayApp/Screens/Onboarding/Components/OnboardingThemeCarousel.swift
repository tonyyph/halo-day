import SwiftUI

struct OnboardingThemeCarousel: View {
    @Binding var selection: String
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.haloReduceMotion) private var reduceMotion

    var body: some View {
        let noMotion = reduceMotion
        ScrollView(.horizontal) {
            LazyHStack(spacing: 16) {
                ForEach(ThemeRegistry.all) { theme in
                    Button {
                        withAnimation(Motion.resolve(Motion.gentle, reduceMotion: reduceMotion)) {
                            selection = theme.id
                        }
                    } label: {
                        ThemeGalleryCard(theme: theme, events: MockData.events(), habits: MockData.habits)
                    }
                    .buttonStyle(PressableStyle())
                    .containerRelativeFrame(.horizontal, count: dynamicType.isAccessibilitySize ? 1 : 2, spacing: 16)
                    .scrollTransition(.interactive) { view, phase in
                        view
                            .scaleEffect(noMotion || phase.isIdentity ? 1 : 0.88)
                            .opacity(noMotion || phase.isIdentity ? 1 : 0.6)
                            .rotation3DEffect(.degrees(noMotion ? 0 : phase.value * 8), axis: (x: 0, y: 1, z: 0))
                    }
                    .id(theme.id)
                    .accessibilityAddTraits(selection == theme.id ? [.isSelected] : [])
                }
            }
            .scrollTargetLayout()
        }
        .frame(height: dynamicType.isAccessibilitySize ? 450 : 340)
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: Binding<String?>(get: { selection }, set: { if let value = $0 { selection = value } }))
    }
}

#Preview("Theme carousel · Light") {
    @Previewable @State var selection = "pearlHalo"
    DesignPreview { OnboardingThemeCarousel(selection: $selection) }
}

#Preview("Theme carousel · Gold AX3") {
    @Previewable @State var selection = "midnightGold"
    DesignPreview(themeID: "midnightGold", scheme: .dark, accessibility: true, reduceMotion: true) {
        OnboardingThemeCarousel(selection: $selection)
    }
}
