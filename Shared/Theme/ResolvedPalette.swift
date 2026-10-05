import SwiftUI

/// Colors are resolved once for each theme and appearance, never in a view body.
struct ResolvedPalette: Sendable {
    let bg, halo, surface, surfaceSunken: Color
    let ink, ink2, ink3, hairline: Color
    let accent, accentInk, accentOn, accentSoft: Color
    let shadowTint, glassStroke: Color

    init(_ source: ThemePalette, dark: Bool) {
        bg = Color(hex: source.bg)
        halo = Color(hex: source.halo)
        surface = Color(hex: source.surface)
        surfaceSunken = Color(hex: source.surfaceSunken)
        ink = Color(hex: source.ink)
        ink2 = Color(hex: source.ink2)
        ink3 = Color(hex: source.ink2).opacity(0.6)
        hairline = Color(hex: source.hairline)
        accent = Color(hex: source.accent)
        accentInk = Color(hex: source.accentInk)
        accentOn = Color(hex: source.accentOn)
        accentSoft = Color(hex: source.accentSoft)
        shadowTint = Color(hex: source.shadowTint)
        glassStroke = .white.opacity(dark ? 0.12 : 0.35)
    }
}

enum PaletteResolver {
    private static let palettes: [String: ResolvedPalette] = Dictionary(
        uniqueKeysWithValues: ThemeRegistry.all.flatMap { theme in
            [
                ("\(theme.id)-light", ResolvedPalette(theme.palette(.light), dark: theme.darkOnly)),
                ("\(theme.id)-dark", ResolvedPalette(theme.palette(.dark), dark: true))
            ]
        }
    )

    static func resolve(_ theme: HaloTheme, scheme: ColorScheme) -> ResolvedPalette {
        palettes["\(theme.id)-\(scheme == .dark ? "dark" : "light")"]!
    }

    static func eventAccent(_ hex: String) -> Color { Color(hex: hex) }
}

private extension Color {
    init(hex: String) {
        let number = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0
        self.init(
            .sRGB,
            red: Double((number >> 16) & 255) / 255,
            green: Double((number >> 8) & 255) / 255,
            blue: Double(number & 255) / 255,
            opacity: 1
        )
    }
}

private struct ResolvedPaletteKey: EnvironmentKey {
    static let defaultValue = PaletteResolver.resolve(ThemeRegistry.all[0], scheme: .light)
}

private struct HaloHapticsKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var palette: ResolvedPalette {
        get { self[ResolvedPaletteKey.self] }
        set { self[ResolvedPaletteKey.self] = newValue }
    }

    var haloHapticsEnabled: Bool {
        get { self[HaloHapticsKey.self] }
        set { self[HaloHapticsKey.self] = newValue }
    }
}
