import SwiftUI
import WidgetKit
import AppIntents

struct PresetEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Halo preset"
    static let defaultQuery = PresetQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}
struct PresetQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [PresetEntity] { available.filter { identifiers.contains($0.id) } }
    func suggestedEntities() async throws -> [PresetEntity] { available }
    private var available: [PresetEntity] { AppGroupStorage.shared.presets.map { PresetEntity(id: $0.id.uuidString, name: $0.name) } }
}
struct HaloConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Your Halo"
    static let description = IntentDescription("Choose a saved preset, or follow your active preset.")
    @Parameter(title: "Preset") var preset: PresetEntity?
}
struct HaloEntry: TimelineEntry {
    var date: Date
    var preset: WidgetPreset
    var snapshot: CalendarSnapshot
    var habits: [Habit]
    var focus: FocusSession?
    var countdown: Countdown?
    var premium: Bool
}
struct HaloTimelineProvider: AppIntentTimelineProvider {
    var type: WidgetType
    func placeholder(in context: Context) -> HaloEntry { sample() }
    func snapshot(for configuration: HaloConfigurationIntent, in context: Context) async -> HaloEntry { context.isPreview ? sample() : entry(configuration, date: .now) }
    func timeline(for configuration: HaloConfigurationIntent, in context: Context) async -> Timeline<HaloEntry> {
        let now = Date.now
        let base = entry(configuration, date: now)
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86400)
        var boundaries = [now, midnight]
        for event in base.snapshot.events {
            boundaries += [event.startDate, event.endDate].filter { $0 > now && $0 < midnight }
        }
        if let focus = base.focus, !focus.isPaused, focus.endDate > now { boundaries.append(focus.endDate) }
        // Progress widgets get precomputed hourly entries, not repeated reload requests.
        for hour in 1...24 { let date = now.addingTimeInterval(Double(hour) * 3600); if date < midnight { boundaries.append(date) } }
        let entries = Set(boundaries).sorted().map { date in var entry = base; entry.date = date; return entry }
        return Timeline(entries: entries, policy: .after(midnight))
    }
    private func entry(_ config: HaloConfigurationIntent, date: Date) -> HaloEntry {
        let storage = AppGroupStorage.shared
        let active = storage.read("activePreset", fallback: "")
        let presetID = config.preset?.id ?? active
        var preset = storage.presets.first { $0.id.uuidString == presetID } ?? WidgetPreset(name: "Halo Day", themeId: storage.settings.selectedThemeId)
        // Each gallery kind retains its purpose; the preset supplies theme/density.
        preset.widgetType = type
        var snapshot = storage.snapshot
        if snapshot.isSample {
            snapshot.events = MockData.events(on: date)
        }
        return HaloEntry(date: date, preset: preset, snapshot: snapshot, habits: storage.habits, focus: storage.focus, countdown: storage.countdowns.first, premium: storage.settings.isPremium)
    }
    private func sample() -> HaloEntry {
        HaloEntry(date: .now, preset: WidgetPreset(name: "Preview", widgetType: type), snapshot: CalendarSnapshot(events: MockData.events()), habits: MockData.habits, focus: nil, countdown: nil, premium: true)
    }
}
struct HaloWidgetView: View {
    var entry: HaloEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    private var size: WidgetSize {
        switch family { case .accessoryInline: .inline; case .accessoryCircular: .circular; case .accessoryRectangular: .rectangular; case .systemSmall: .small; case .systemMedium: .medium; default: .large }
    }
    private var locked: Bool { !entry.premium && (entry.preset.widgetType.premium || [.medium, .large].contains(size) || ThemeRegistry.theme(entry.preset.themeId).isPremium) }
    private var destination: String {
        if locked { return "paywall" }
        return switch entry.preset.widgetType { case .focus: "focus"; case .habit, .ritual: "rituals"; default: "today" }
    }
    var body: some View {
        let theme = ThemeRegistry.theme(entry.preset.themeId)
        Group {
            if locked {
                Label("Unlock in Halo Day", systemImage: "sparkle").font(.caption)
            } else {
                HaloWidgetContent(date: entry.date, type: entry.preset.widgetType, size: size, theme: theme, events: entry.snapshot.events, habits: entry.habits, focus: entry.focus, countdown: entry.countdown, sample: entry.snapshot.isSample, interactive: !size.isAccessory && entry.premium)
            }
        }.containerBackground(for: .widget) { PaletteResolver.resolve(theme, scheme: scheme).bg }
            .widgetURL(URL(string: "haloday://\(destination)"))
    }
}
struct HaloPlannerWidget: Widget {
    var type: WidgetType
    init() { type = .agenda }
    init(type: WidgetType) { self.type = type }
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Halo.\(type.rawValue)", intent: HaloConfigurationIntent.self, provider: HaloTimelineProvider(type: type)) { HaloWidgetView(entry: $0) }
            .configurationDisplayName(LocalizedStringKey(type.title))
            .description("Your day, beautifully on display.")
            .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular, .systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct HaloWidgetBundle: WidgetBundle {
    var body: some Widget {
        HaloPlannerWidget(type: .agenda)
        HaloPlannerWidget(type: .month)
        HaloPlannerWidget(type: .week)
        HaloPlannerWidget(type: .mini)
        HaloPlannerWidget(type: .habit)
        HaloPlannerWidget(type: .focus)
        HaloPlannerWidget(type: .countdown)
        HaloPlannerWidget(type: .ritual)
        HaloFocusLiveActivity()
    }
}
