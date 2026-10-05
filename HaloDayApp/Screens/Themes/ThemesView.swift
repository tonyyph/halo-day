import SwiftUI

struct ThemesView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicType

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: dynamicType.isAccessibilitySize ? 1 : 2)
    }

    var body: some View {
        HaloScreen {
            SectionTitle(title: "Eight ways to glow", subtitle: "A look for every kind of day.")
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(ThemeRegistry.all) { theme in
                    NavigationLink {
                        ThemeDetailView(theme: theme)
                            .haloZoomDestination("theme-\(theme.id)")
                    } label: {
                        ThemeGalleryCard(
                            theme: theme,
                            events: model.todayEvents,
                            habits: model.habits,
                            premium: model.purchases.isPremium
                        )
                    }
                    .buttonStyle(PressableStyle())
                    .haloZoomSource("theme-\(theme.id)")
                    .accessibilityIdentifier("theme-\(theme.id)")
                }
            }
        }
    }
}

struct ThemeDetailView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Environment(\.haloReduceMotion) private var reduceMotion
    @Environment(\.haloHapticsEnabled) private var haptics
    @State private var page = 0
    @State private var selectedToken: Int?
    var theme: HaloTheme

    private var locked: Bool { theme.isPremium && !model.purchases.isPremium }
    private var palette: ResolvedPalette { PaletteResolver.resolve(theme, scheme: scheme) }

    var body: some View {
        HaloScreen {
            SectionTitle(title: theme.name, subtitle: theme.mood)
            if locked { PremiumChip(preview: true) }

            TabView(selection: $page) {
                phone(.rectangular).tag(0)
                phone(.medium).tag(1)
                activityPreview.tag(2)
            }
            .frame(height: 370)
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? palette.accent : palette.hairline)
                        .frame(width: index == page ? 20 : 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)

            paletteStrip

            Text("Full theme color in the app, Home Screen widgets and Live Activities. Lock Screen widgets follow your wallpaper.")
                .haloFont(.subhead)
                .foregroundStyle(palette.ink2)

            HaloButton(title: locked ? "Unlock with Premium" : model.theme.id == theme.id ? "Applied" : "Apply theme") {
                model.applyTheme(theme)
            }
        }
        .haloTheme(theme)
        .animation(Motion.resolve(Motion.snappy, reduceMotion: reduceMotion), value: selectedToken)
        .sensoryFeedback(.selection, trigger: selectedToken) { _, _ in haptics }
    }

    private func phone(_ size: WidgetSize) -> some View {
        PhonePreview(
            preset: WidgetPreset(name: theme.name, widgetFamily: size, themeId: theme.id),
            events: model.todayEvents,
            habits: model.habits,
            focus: model.focus,
            countdown: model.countdowns.first,
            sample: model.isSample
        )
        .scaleEffect(0.78)
        .frame(maxWidth: .infinity)
    }

    private var activityPreview: some View {
        let start = Date.now
        return HaloActivityBanner(
            attributes: HaloActivityAttributes(
                title: String(localized: "Deep work"), startDate: start,
                endDate: start.addingTimeInterval(3000), themeId: theme.id, accentColor: theme.dark.accent
            ),
            state: .init(endDate: start.addingTimeInterval(3000)), interactive: false
        )
        .background(PaletteResolver.resolve(theme, scheme: .dark).surface,
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(16)
    }

    private var paletteStrip: some View {
        let tokens: [(String, Color)] = [
            ("Background", palette.bg), ("Accent", palette.accent),
            ("Surface", palette.surface), ("Text", palette.ink), ("Border", palette.hairline)
        ]
        return HStack(alignment: .top, spacing: 8) {
            ForEach(tokens.indices, id: \.self) { index in
                Button { selectedToken = selectedToken == index ? nil : index } label: {
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(tokens[index].1)
                            .frame(height: 42)
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(palette.hairline, lineWidth: 0.5)
                            }
                        Text(LocalizedStringKey(tokens[index].0))
                            .haloFont(.caption)
                            .foregroundStyle(palette.ink2)
                            .opacity(selectedToken == index ? 1 : 0)
                    }
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(Text(LocalizedStringKey(tokens[index].0)))
            }
        }
    }
}

#Preview("Themes · Light") {
    NavigationStack { ThemesView() }.environment(HaloModel())
        .haloTheme(ThemeRegistry.theme("pearlHalo"))
}

#Preview("Themes · Gold AX3") {
    NavigationStack { ThemesView() }.environment(HaloModel())
        .haloTheme(ThemeRegistry.theme("midnightGold"))
        .environment(\.dynamicTypeSize, .accessibility3)
        .environment(\.haloReduceMotionOverride, true)
}
