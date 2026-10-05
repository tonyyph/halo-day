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

    init(vibrant scheme: ColorScheme) {
        let primary: Color = scheme == .dark ? .white : .black
        bg = .clear; halo = .clear; surface = .clear; surfaceSunken = primary.opacity(0.08)
        ink = primary; ink2 = primary.opacity(0.6); ink3 = primary.opacity(0.35)
        hairline = primary.opacity(0.15)
        accent = primary; accentInk = primary
        accentOn = scheme == .dark ? .black : .white
        accentSoft = primary.opacity(0.12)
        shadowTint = .clear; glassStroke = primary.opacity(0.12)
    }
}

enum PaletteResolver {
    private static let eventColors = EventColorCache()
    private static let vibrantLight = ResolvedPalette(vibrant: .light)
    private static let vibrantDark = ResolvedPalette(vibrant: .dark)
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

    static func eventAccent(_ hex: String) -> Color { eventColors.color(hex) }
    static func vibrant(_ scheme: ColorScheme) -> ResolvedPalette {
        scheme == .dark ? vibrantDark : vibrantLight
    }
}

private final class ResolvedColorBox: NSObject {
    let value: Color
    init(_ value: Color) { self.value = value }
}

/// NSCache is thread safe; calendar colors are shared by app and widget renderers.
private final class EventColorCache: @unchecked Sendable {
    private let cache = NSCache<NSString, ResolvedColorBox>()

    init() { cache.countLimit = 128 }

    func color(_ hex: String) -> Color {
        let key = hex as NSString
        if let resolved = cache.object(forKey: key) { return resolved.value }
        let resolved = Color(hex: hex)
        cache.setObject(ResolvedColorBox(resolved), forKey: key)
        return resolved
    }
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

private struct MotionOverrideKey: EnvironmentKey { static let defaultValue = false }
private struct TransparencyOverrideKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    var palette: ResolvedPalette {
        get { self[ResolvedPaletteKey.self] }
        set { self[ResolvedPaletteKey.self] = newValue }
    }

    var haloHapticsEnabled: Bool {
        get { self[HaloHapticsKey.self] }
        set { self[HaloHapticsKey.self] = newValue }
    }

    var haloReduceMotionOverride: Bool {
        get { self[MotionOverrideKey.self] }
        set { self[MotionOverrideKey.self] = newValue }
    }

    var haloReduceMotion: Bool { accessibilityReduceMotion || haloReduceMotionOverride }

    var haloReduceTransparencyOverride: Bool {
        get { self[TransparencyOverrideKey.self] }
        set { self[TransparencyOverrideKey.self] = newValue }
    }

    var haloReduceTransparency: Bool {
        accessibilityReduceTransparency || haloReduceTransparencyOverride
    }
}
