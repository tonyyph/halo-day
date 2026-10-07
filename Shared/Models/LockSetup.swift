import Foundation

enum AccessoryFamily: String, Codable, Sendable, CaseIterable {
    case inline, circular, rectangular
    /// Width in the Lock Screen row below the clock (4 units).
    var units: Int {
        switch self {
        case .inline: 0
        case .circular: 1
        case .rectangular: 2
        }
    }
}

/// v2 widget kinds (spec §5).
enum WidgetKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case orbit, nextUp, rhythm, rituals, countdown, month
    var id: String { rawValue }
    var title: String {
        switch self {
        case .orbit: String(localized: "Orbit")
        case .nextUp: String(localized: "Next up")
        case .rhythm: String(localized: "Rhythm")
        case .rituals: String(localized: "Rituals")
        case .countdown: String(localized: "Countdown")
        case .month: String(localized: "Month")
        }
    }
    var symbol: String {
        switch self {
        case .orbit: "circle.dashed"
        case .nextUp: "arrow.right.circle"
        case .rhythm: "list.bullet"
        case .rituals: "circle.grid.cross"
        case .countdown: "hourglass"
        case .month: "calendar"
        }
    }
    /// Lock Screen families this kind can take.
    var families: [AccessoryFamily] {
        switch self {
        case .orbit, .rituals: [.circular]
        case .nextUp: [.rectangular, .inline]
        case .rhythm: [.rectangular]
        case .countdown: [.circular, .rectangular]
        case .month: [.inline, .rectangular]
        }
    }
    var isPremium: Bool { self == .rhythm || self == .rituals }
    init(legacy: WidgetType) {
        switch legacy {
        case .agenda: self = .rhythm
        case .week, .mini, .month: self = .month
        case .habit, .ritual: self = .rituals
        case .focus: self = .orbit
        case .countdown: self = .countdown
        }
    }
}

struct LockSlot: Codable, Hashable, Sendable, Identifiable {
    var id = UUID()
    var kind: WidgetKind
    var family: AccessoryFamily
}

/// One Lock Screen: a sky wallpaper, an optional inline line above the clock and up to four units of widgets below it.
struct LockSetup: Codable, Hashable, Sendable, Identifiable {
    static let rowUnits = 4
    var id = UUID()
    var name: String
    var skyID: SkyID = .livingSky
    var inline: WidgetKind? = .month
    var slots: [LockSlot] = []
    var wallpaperShowsOrbit = true
    /// When set, the wallpaper carries the agenda (week, month or Orbit) instead of the plain sky.
    var agenda: AgendaWallpaper?

    var usedUnits: Int { slots.reduce(0) { $0 + $1.family.units } }
    var remainingUnits: Int { max(0, Self.rowUnits - usedUnits) }
    var isValid: Bool {
        usedUnits <= Self.rowUnits
            && slots.allSatisfy { $0.family != .inline && $0.kind.families.contains($0.family) }
            && (inline.map { $0.families.contains(.inline) } ?? true)
    }
    var isPremium: Bool { skyID.isPremium || slots.contains { $0.kind.isPremium } || inline?.isPremium == true }

    /// Premium content this version adds over the stored one. Content a person already had (for example migrated
    /// from v1, or kept after Premium lapsed) is not re-gated, so ordinary edits never hit the paywall.
    func addsPremium(over stored: LockSetup?) -> Bool {
        let kept = Set((stored?.slots.map(\.kind) ?? []) + [stored?.inline].compactMap { $0 })
        if skyID.isPremium && skyID != stored?.skyID { return true }
        if let inline, inline.isPremium && !kept.contains(inline) { return true }
        return slots.contains { $0.kind.isPremium && !kept.contains($0.kind) }
    }

    static func starter(name: String, sky: SkyID) -> LockSetup {
        LockSetup(name: name, skyID: sky, inline: .month,
                  slots: [LockSlot(kind: .nextUp, family: .rectangular), LockSlot(kind: .orbit, family: .circular), LockSlot(kind: .countdown, family: .circular)])
    }

    init(id: UUID = UUID(), name: String, skyID: SkyID = .livingSky, inline: WidgetKind? = .month, slots: [LockSlot] = [], wallpaperShowsOrbit: Bool = true, agenda: AgendaWallpaper? = nil) {
        self.id = id; self.name = name; self.skyID = skyID; self.inline = inline; self.slots = slots; self.wallpaperShowsOrbit = wallpaperShowsOrbit
        self.agenda = agenda
    }

    /// A v1 preset becomes a setup with its theme as a sky and its widget as the first slot.
    init(legacy preset: WidgetPreset) {
        var settings = UserSettings()
        settings.selectedThemeId = preset.themeId
        let kind = WidgetKind(legacy: preset.widgetType)
        let family: AccessoryFamily = kind.families.contains(.rectangular) && preset.widgetFamily != .circular ? .rectangular : (kind.families.first { $0 != .inline } ?? .rectangular)
        self.init(id: preset.id, name: preset.name, skyID: settings.skyID, inline: .month, slots: [LockSlot(kind: kind, family: family)])
    }
}

extension LockSetup {
    private enum CodingKeys: String, CodingKey { case id, name, skyID, inline, slots, wallpaperShowsOrbit, agenda }
    /// Tolerant decoding: fields added later (or dropped) fall back to defaults instead of failing the whole list.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try container.decode(UUID.self, forKey: .id),
                  name: try container.decodeIfPresent(String.self, forKey: .name) ?? String(localized: "My Halo"),
                  skyID: (try? container.decodeIfPresent(SkyID.self, forKey: .skyID)) ?? .livingSky,
                  inline: try? container.decodeIfPresent(WidgetKind.self, forKey: .inline),
                  slots: (try? container.decodeIfPresent([LockSlot].self, forKey: .slots)) ?? [],
                  wallpaperShowsOrbit: try container.decodeIfPresent(Bool.self, forKey: .wallpaperShowsOrbit) ?? true,
                  agenda: try? container.decodeIfPresent(AgendaWallpaper.self, forKey: .agenda))
    }
}
