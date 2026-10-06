import SwiftUI

/// "Halo today" — a 9:16 card of the day's sky and Orbit for sharing. Event names only when asked.
struct ShareCardArt: View {
    var scene: DayScene
    var sky: SkyState
    var style: OrbitStyle
    var showTitles: Bool
    var events: [CalendarEvent]
    var isSample: Bool

    static func lines(events: [CalendarEvent], showTitles: Bool) -> [String] {
        guard showTitles else { return [] }
        return events.filter { !$0.isAllDay }.sorted { $0.startDate < $1.startDate }.prefix(4)
            .map { "\($0.startDate.formatted(date: .omitted, time: .shortened))  \($0.title)" }
    }

    var body: some View {
        ZStack {
            SkyBackground(state: sky)
            VStack(spacing: 18) {
                Text(scene.day, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(DS.Typeface.title(24))
                    .padding(.top, 48)
                OrbitCanvas(content: scene.orbit, sky: sky, style: style)
                    .frame(width: 280, height: 280)
                Text(summary).font(.subheadline.weight(.medium))
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Self.lines(events: events, showTitles: showTitles), id: \.self) { line in
                        Text(verbatim: line).font(.footnote)
                    }
                }
                Spacer()
                if isSample { Text("Sample day").font(.caption).opacity(SkyEngine.secondaryOpacity) }
                Text(verbatim: "Halo Day").font(DS.Typeface.display(20)).padding(.bottom, 28)
            }
            .padding(.horizontal, 28)
        }
        .foregroundStyle(sky.inkColor.color)
        .environment(\.colorScheme, sky.ink == .light ? .dark : .light)
    }

    private var summary: String {
        var parts = [String(localized: "\(scene.ritualsDone)/\(scene.ritualsTotal) rituals")]
        if scene.focusMinutes > 0 { parts.append(String(localized: "\(scene.focusMinutes)′ focused")) }
        parts.append(String(localized: "\(events.filter { !$0.isAllDay }.count) events"))
        return parts.joined(separator: " · ")
    }
}
