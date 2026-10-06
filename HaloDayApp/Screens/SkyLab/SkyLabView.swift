#if DEBUG
import SwiftUI

enum SkyLabPlace: String, CaseIterable, Identifiable {
    case hanoi, london, tromso, sydney
    var id: String { rawValue }
    var name: String {
        switch self { case .hanoi: "Hà Nội"; case .london: "London"; case .tromso: "Tromsø"; case .sydney: "Sydney" }
    }
    var coordinate: GeoCoordinate {
        switch self {
        case .hanoi: GeoCoordinate(latitude: 21.03, longitude: 105.85)
        case .london: GeoCoordinate(latitude: 51.51, longitude: -0.13)
        case .tromso: GeoCoordinate(latitude: 69.65, longitude: 18.96)
        case .sydney: GeoCoordinate(latitude: -33.87, longitude: 151.21)
        }
    }
    var timeZone: TimeZone {
        let identifier = switch self {
        case .hanoi: "Asia/Ho_Chi_Minh"; case .london: "Europe/London"; case .tromso: "Europe/Oslo"; case .sydney: "Australia/Sydney"
        }
        return TimeZone(identifier: identifier)!
    }
}

enum SkyLabSeason: String, CaseIterable, Identifiable {
    case march, june, october, december
    var id: String { rawValue }
    var components: (month: Int, day: Int) {
        switch self { case .march: (3, 20); case .june: (6, 21); case .october: (10, 5); case .december: (12, 21) }
    }
}

/// Developer screen for judging the sky and Orbit at any minute, place, season and sky.
struct SkyLabView: View {
    @State var minutes: Double
    @State var sky: SkyID
    @State var place: SkyLabPlace
    @State var season: SkyLabSeason

    init(minutes: Int, sky: SkyID, place: SkyLabPlace, season: SkyLabSeason) {
        _minutes = State(initialValue: Double(minutes)); _sky = State(initialValue: sky)
        _place = State(initialValue: place); _season = State(initialValue: season)
    }

    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = place.timeZone; return c }
    private var day: Date { calendar.date(from: DateComponents(year: 2026, month: season.components.month, day: season.components.day))! }
    private var date: Date { day.addingTimeInterval(minutes * 60) }
    private var state: SkyState { SkyEngine.state(sky: sky, at: date, coordinate: place.coordinate, calendar: calendar) }

    private var content: OrbitContent {
        let events: [CalendarEvent] = [(8.0, 8.75, "6F86D8"), (10.5, 11.25, "E2607D"), (12.0, 13.0, "5B9AD6"), (14.5, 15.0, "E3A050"), (17.0, 18.0, "4FAE86"), (19.5, 21.0, "9B6FD0")]
            .enumerated().map { index, item in
                CalendarEvent(id: "lab-\(index)", title: "Event \(index)", startDate: day.addingTimeInterval(item.0 * 3600),
                              endDate: day.addingTimeInterval(item.1 * 3600), calendarName: "Lab", accentColor: item.2)
            }
        let solar = SolarCalculator.day(containing: day, coordinate: place.coordinate, calendar: calendar)
        return OrbitContent(layout: OrbitLayout(day: day, events: events, calendar: calendar),
                            beads: [OrbitBead(id: UUID(), hour: 7, isDone: true, colorHex: "E0904A"),
                                    OrbitBead(id: UUID(), hour: 8.3, isDone: true, colorHex: "E0904A"),
                                    OrbitBead(id: UUID(), hour: 21, isDone: false, colorHex: "E0904A")],
                            focusSpans: [9...9.4],
                            nightSpans: OrbitGeometry.nightSpans(solar, calendar: calendar),
                            nowHour: minutes / 60,
                            moonPhase: SolarCalculator.moonPhase(at: date))
    }

    var body: some View {
        let state = state
        let ink = state.inkColor.color
        ZStack {
            SkyBackground(state: state)
            VStack(spacing: DS.Space.l) {
                VStack(spacing: DS.Space.xs) {
                    Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.current)))
                        .font(DS.Typeface.title(20))
                    Text(verbatim: "\(sky.title) · \(place.name) · \(Int(state.sunAltitude))°")
                        .font(.footnote).opacity(SkyEngine.secondaryOpacity)
                }
                .padding(.top, DS.Space.xl)
                ZStack {
                    OrbitCanvas(content: content, sky: state, style: sky.orbitStyle, breathing: true)
                    VStack(spacing: 2) {
                        Text(String(format: "%02d:%02d", Int(minutes) / 60, Int(minutes) % 60))
                            .font(DS.Typeface.clock(320 * 0.14))
                        Text(state.moment.title)
                            .font(DS.Typeface.moment(17))
                            .opacity(SkyEngine.secondaryOpacity)
                            .accessibilityIdentifier("skylab-moment")
                    }
                }
                .frame(width: 320, height: 320)
                Text(verbatim: "Ngày của bạn, như một vòng sáng. Đường, ỡ ự ẳ")
                    .font(DS.Typeface.display(30))
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
                VStack(spacing: DS.Space.m) {
                    Slider(value: $minutes, in: 0...1439, step: 5).accessibilityIdentifier("skylab-slider")
                    Picker(selection: $sky) { ForEach(SkyID.allCases) { Text($0.title).tag($0) } } label: { Text(verbatim: "sky") }.pickerStyle(.menu)
                    Picker(selection: $place) { ForEach(SkyLabPlace.allCases) { Text($0.name).tag($0) } } label: { Text(verbatim: "place") }.pickerStyle(.segmented)
                    Picker(selection: $season) { ForEach(SkyLabSeason.allCases) { Text($0.rawValue.capitalized).tag($0) } } label: { Text(verbatim: "season") }.pickerStyle(.segmented)
                }
                .padding(DS.Space.l)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.glass, style: .continuous))
                .environment(\.colorScheme, state.ink == .light ? .dark : .light)
            }
            .padding(.horizontal, DS.Space.l)
            .foregroundStyle(ink)
            .tint(ink)
        }
        .animation(DS.Motion.inkFlip, value: state.ink)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("skylab-root")
    }
}
#endif
