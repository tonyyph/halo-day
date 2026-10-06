import SwiftUI
import WidgetKit
import AppIntents

// MARK: Configuration

struct SetupEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Halo setup"
    static let defaultQuery = SetupQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct SetupQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [SetupEntity] { available.filter { identifiers.contains($0.id) } }
    func suggestedEntities() async throws -> [SetupEntity] { available }
    private var available: [SetupEntity] { AppGroupStorage.shared.setups.map { SetupEntity(id: $0.id.uuidString, name: $0.name) } }
}

struct HaloSetupIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Halo setup"
    static let description = IntentDescription("Choose a setup from Studio, or follow the one in use.")
    @Parameter(title: "Setup") var setup: SetupEntity?
}

// MARK: Timeline

struct HaloEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot
}

struct HaloProvider: AppIntentTimelineProvider {
    var kind: WidgetKind

    func placeholder(in context: Context) -> HaloEntry { sample(.now) }

    func snapshot(for configuration: HaloSetupIntent, in context: Context) async -> HaloEntry {
        context.isPreview ? sample(.now) : entry(configuration, date: .now)
    }

    func timeline(for configuration: HaloSetupIntent, in context: Context) async -> Timeline<HaloEntry> {
        let now = Date.now
        let base = entry(configuration, date: now)
        // Home Screen / StandBy widgets show the sky, so they also refresh hourly; Lock Screen ones only at boundaries.
        let hourly = ![.accessoryInline, .accessoryCircular, .accessoryRectangular].contains(context.family)
        let dates = WidgetTimeline.entryDates(now: now, events: base.snapshot.data.events, focus: base.snapshot.data.focus, hourly: hourly)
        let entries = dates.map { date in
            var next = base
            next.date = date
            next.snapshot.data.date = date
            return next
        }
        return Timeline(entries: entries, policy: .after(dates.last ?? now.addingTimeInterval(3600)))
    }

    private func entry(_ configuration: HaloSetupIntent, date: Date) -> HaloEntry {
        HaloEntry(date: date, snapshot: WidgetSnapshot.load(storage: .shared, date: date, setupID: configuration.setup.flatMap { UUID(uuidString: $0.id) }))
    }

    private func sample(_ date: Date) -> HaloEntry {
        HaloEntry(date: date, snapshot: WidgetSnapshot(
            data: WidgetData(date: date, events: MockData.events(on: date), habits: MockData.habits, focus: nil,
                             countdown: Countdown(title: String(localized: "Lisbon"), targetDate: date.addingTimeInterval(12 * 86400)), isSample: true),
            setup: .starter(name: String(localized: "My Halo"), sky: .livingSky), isPremium: true,
            coordinate: TimeZoneLocator.approximateCoordinate(for: .current, at: date)))
    }
}

// MARK: Views

struct HaloWidgetEntryView: View {
    var kind: WidgetKind
    var entry: HaloEntry
    @Environment(\.widgetFamily) private var family

    private var locked: Bool { kind.isPremium && !entry.snapshot.isPremium }

    var body: some View {
        let snapshot = entry.snapshot
        Group {
            switch family {
            case .accessoryInline, .accessoryCircular, .accessoryRectangular:
                let accessory: AccessoryFamily = family == .accessoryInline ? .inline : family == .accessoryCircular ? .circular : .rectangular
                Group {
                    if locked {
                        Label("Premium", systemImage: "sparkles")
                    } else {
                        AccessoryView(kind: kind, family: accessory, data: snapshot.data, tint: nil)
                    }
                }
                .widgetAccentable()
                .containerBackground(for: .widget) { Color.clear }
            default:
                let sky = SkyEngine.state(sky: snapshot.setup.skyID, at: entry.date, coordinate: snapshot.coordinate)
                let home: HomeFamily = family == .systemLarge || family == .systemExtraLarge ? .large : family == .systemMedium ? .medium : .small
                HomeWidgetView(kind: kind, family: home, data: snapshot.data, sky: sky, style: snapshot.setup.skyID.orbitStyle,
                               coordinate: snapshot.coordinate, locked: locked, interactive: !locked)
                    .containerBackground(for: .widget) { SkyBackground(state: sky) }
            }
        }
        .widgetURL(locked ? URL(string: "haloday://paywall") : kind.url(for: snapshot.data))
    }
}

struct HaloKindWidget: Widget {
    var kind: WidgetKind
    init() { kind = .orbit }
    init(kind: WidgetKind) { self.kind = kind }

    private var families: [WidgetFamily] {
        kind.families.map { family -> WidgetFamily in
            switch family {
            case .inline: .accessoryInline
            case .circular: .accessoryCircular
            case .rectangular: .accessoryRectangular
            }
        } + kind.homeFamilies.map { family -> WidgetFamily in
            switch family {
            case .small: .systemSmall
            case .medium: .systemMedium
            case .large: .systemLarge
            }
        }
    }

    private var summary: LocalizedStringKey {
        switch kind {
        case .orbit: "Your day as a ring of light."
        case .nextUp: "What's next, at a glance."
        case .rhythm: "The rest of your day."
        case .rituals: "Keep your rituals with a tap."
        case .countdown: "Days to what matters."
        case .month: "Where you are in the month."
        }
    }

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Halo.v2.\(kind.rawValue)", intent: HaloSetupIntent.self, provider: HaloProvider(kind: kind)) { entry in
            HaloWidgetEntryView(kind: kind, entry: entry)
        }
        .configurationDisplayName(Text(kind.title))
        .description(summary)
        .supportedFamilies(families)
    }
}

@main
struct HaloWidgetBundle: WidgetBundle {
    init() { HaloFonts.registerIfNeeded() }
    var body: some Widget {
        HaloKindWidget(kind: .orbit)
        HaloKindWidget(kind: .nextUp)
        HaloKindWidget(kind: .rhythm)
        HaloKindWidget(kind: .rituals)
        HaloKindWidget(kind: .countdown)
        HaloKindWidget(kind: .month)
        HaloFocusLiveActivity()
    }
}
