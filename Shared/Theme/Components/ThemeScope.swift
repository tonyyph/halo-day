import SwiftUI

private struct ThemeScopeModifier: ViewModifier {
    let theme: HaloTheme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.haloReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let colors = PaletteResolver.resolve(theme, scheme: theme.darkOnly ? .dark : scheme)
        content
            .environment(\.haloTheme, theme)
            .environment(\.palette, colors)
            .foregroundStyle(colors.ink)
            .tint(colors.accentInk)
            .preferredColorScheme(theme.darkOnly ? .dark : nil)
            .animation(Motion.resolve(Motion.gentle, reduceMotion: reduceMotion), value: theme.id)
    }
}

extension View {
    func haloTheme(_ theme: HaloTheme) -> some View { modifier(ThemeScopeModifier(theme: theme)) }
}

struct DesignPreview<Content: View>: View {
    var themeID = "pearlHalo"
    var scheme: ColorScheme = .light
    var accessibility = false
    var reduceMotion = false
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            ThemeBackground()
            ScrollView { content.padding(24) }
        }
        .environment(\.palette, PaletteResolver.resolve(ThemeRegistry.theme(themeID), scheme: scheme))
        .environment(\.haloTheme, ThemeRegistry.theme(themeID))
        .environment(\.haloReduceMotionOverride, reduceMotion)
        .environment(\.dynamicTypeSize, accessibility ? .accessibility3 : .large)
        .preferredColorScheme(scheme)
    }
}
