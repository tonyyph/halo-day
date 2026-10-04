import SwiftUI

struct ThemePalette: Codable, Hashable, Sendable {
    var bg, halo, surface, surfaceSunken, ink, ink2, hairline, accent, accentInk, accentOn, accentSoft, shadowTint: String
    init(_ values: [String]) {
        bg = values[0]; halo = values[1]; surface = values[2]; surfaceSunken = values[3]
        ink = values[4]; ink2 = values[5]; hairline = values[6]; accent = values[7]
        accentInk = values[8]; accentOn = values[9]; accentSoft = values[10]; shadowTint = values[11]
    }
}
struct HaloTheme: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var name: String
    var mood: String
    var isPremium: Bool
    var light: ThemePalette
    var dark: ThemePalette
    var darkOnly = false
    var widgetStyle: String
    var displayName: String { name }
    var backgroundColor: String { light.bg }
    var glassColor: String { light.surface }
    var accentColor: String { light.accent }
    var primaryText: String { light.ink }
    var secondaryText: String { light.ink2 }
    var borderColor: String { light.hairline }
    var shadowColor: String { light.shadowTint }
    var blurStyle: String { "ultraThinMaterial" }
    var cornerRadius: Double { HaloTokens.Radius.hero }
    var typographyStyle: String { widgetStyle }
    func palette(_ scheme: ColorScheme) -> ThemePalette { scheme == .dark || darkOnly ? dark : light }
}
enum ThemeRegistry {
    static let all: [HaloTheme] = [
        HaloTheme(id: "pearlHalo", name: "Pearl Halo", mood: "Soft morning light. Quiet luxury.", isPremium: false,
          light: .init(["F6F3EF","EADFD6","FFFFFF","EFEBE5","1D1B1E","6B6670","E3DDD5","9A8572","74604E","1D1B1E","EFE6DC","5A4636"]),
          dark: .init(["121113","2A2422","1C1A1C","161416","F3F0EC","A8A2A6","2C292C","C9B5A0","D4C2AE","1D1B1E","2B2520","000000"]), widgetStyle: "airy"),
        HaloTheme(id: "rubyGlass", name: "Ruby Glass", mood: "A single drop of red on frosted glass.", isPremium: false,
          light: .init(["F7F1EF","F2D3D6","FFFFFF","F1E7E5","1E1214","6E5A5D","EADCDB","B0152F","A3122B","FFFFFF","F6DADF","5A0E1B"]),
          dark: .init(["140B0D","3A1218","1F1215","190E11","F7ECEC","B49EA1","33201F","D52D48","F0627A","FFFFFF","3B1219","000000"]), widgetStyle: "glass"),
        HaloTheme(id: "champagneDay", name: "Champagne Day", mood: "Golden hour, on warm cream paper.", isPremium: true,
          light: .init(["FAF6EE","F1E3C6","FFFDF8","F2ECDF","2A2418","76694F","E8DEC9","B8925A","7F6131","2A2418","F3E7D1","6B5226"]),
          dark: .init(["15120C","33291A","1F1A12","19150E","F6EFE1","B9AB8E","342B1D","D7B278","DDBB86","1A150C","33291A","000000"]), widgetStyle: "editorial"),
        HaloTheme(id: "graphiteFocus", name: "Graphite Focus", mood: "Studio at night. Space to think.", isPremium: false,
          light: .init(["0E0F11","1F2226","17191C","121316","F2F1EE","9A9DA3","26292E","E6E1D6","E6E1D6","0E0F11","24262A","000000"]),
          dark: .init(["0E0F11","1F2226","17191C","121316","F2F1EE","9A9DA3","26292E","E6E1D6","E6E1D6","0E0F11","24262A","000000"]), darkOnly: true, widgetStyle: "technical"),
        HaloTheme(id: "emeraldRitual", name: "Emerald Ritual", mood: "Botanical calm. Small daily things.", isPremium: true,
          light: .init(["F2F4EF","D7E6DA","FFFFFF","E8ECE5","14231C","5A6B62","DCE3DA","0F6B4C","0F6B4C","FFFFFF","D6E9DF","0F3B2A"]),
          dark: .init(["0B1712","173328","12211B","0E1B16","EAF2EC","9DB2A6","1F3329","3FAE84","5CC79C","0B1712","163327","000000"]), widgetStyle: "organic"),
        HaloTheme(id: "roseAtelier", name: "Rose Atelier", mood: "Blush silk. A little Paris.", isPremium: true,
          light: .init(["FBF3F1","F4D9D6","FFFFFF","F4E8E5","2B1C1E","7A6265","EEDDDA","99474E","99474E","FFFFFF","F6E1E1","6B3238"]),
          dark: .init(["1A1113","3A2226","24181B","1E1417","F8ECEB","BFA5A8","3A2A2D","E09AA0","E8AAAF","2B1C1E","3A2427","000000"]), widgetStyle: "atelier"),
        HaloTheme(id: "ivoryMinimal", name: "Ivory Minimal", mood: "Paper and ink. Nothing extra.", isPremium: true,
          light: .init(["FBFAF6","F1EEE6","FFFFFF","F3F1EB","151515","6F6D68","E6E3DA","151515","151515","FBFAF6","ECE9E1","2A2A2A"]),
          dark: .init(["0F0F0E","1C1B19","181816","131312","F5F3EE","A3A09A","2A2926","F5F3EE","F5F3EE","0F0F0E","22211F","000000"]), widgetStyle: "minimal"),
        HaloTheme(id: "midnightGold", name: "Midnight Gold", mood: "Black-tie evening. A hint of gold.", isPremium: true,
          light: .init(["0A0C14","1E2235","131726","0E111C","F4EFE4","A7A291","252A3D","D4AF6A","DDBC7E","0A0C14","2A2618","000000"]),
          dark: .init(["0A0C14","1E2235","131726","0E111C","F4EFE4","A7A291","252A3D","D4AF6A","DDBC7E","0A0C14","2A2618","000000"]), darkOnly: true, widgetStyle: "gilded")
    ]
    static func theme(_ id: String) -> HaloTheme { all.first { $0.id == id } ?? all[0] }
}
enum HaloTokens {
    enum Space { static let tiny: CGFloat = 4; static let small: CGFloat = 8; static let row: CGFloat = 12; static let card: CGFloat = 16; static let hero: CGFloat = 20; static let section: CGFloat = 24; static let major: CGFloat = 32; static let onboarding: CGFloat = 40 }
    enum Radius { static let small: CGFloat = 10; static let card: CGFloat = 16; static let hero: CGFloat = 22; static let phone: CGFloat = 32 }
    static let display: Font = .system(.largeTitle, design: .serif)
    static let title: Font = .system(.title2, design: .serif)
}
extension Color {
    init(hex: String) {
        let number = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0
        self.init(.sRGB, red: Double((number >> 16) & 255) / 255, green: Double((number >> 8) & 255) / 255, blue: Double(number & 255) / 255, opacity: 1)
    }
}
private struct HaloThemeKey: EnvironmentKey { static let defaultValue = ThemeRegistry.all[0] }
extension EnvironmentValues {
    var haloTheme: HaloTheme { get { self[HaloThemeKey.self] } set { self[HaloThemeKey.self] = newValue } }
}
