import SwiftUI
import WidgetKit

struct WidgetAgendaRows: View {
    private struct Row: Identifiable {
        let event: CalendarEvent
        let url: URL
        var id: String { event.id }
    }
    private let rows: [Row]
    var date: Date
    var style: WidgetStyle
    @Environment(\.palette) private var palette

    init(events: [CalendarEvent], date: Date, style: WidgetStyle) {
        self.date = date; self.style = style
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        rows = events.map { event in
            let path = event.id.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
            return Row(event: event, url: URL(string: "haloday://event/\(path)")!)
        }
    }

    var body: some View {
        ForEach(rows) { row in
            let event = row.event
            Link(destination: row.url) {
                HStack(alignment: .top, spacing: 7) {
                    Text(event.startDate, style: .time)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(palette.ink2)
                        .frame(minWidth: 40, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            if event.startDate <= date && event.endDate > date { WidgetNowMarker(style: style.nowMarker) }
                            Text(event.title)
                                .font(.system(.caption, design: style.titleDesign))
                                .lineLimit(1)
                                .privacySensitive()
                        }
                        if let location = event.location {
                            Text(location).font(.caption2).lineLimit(1).foregroundStyle(palette.ink3)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .opacity(event.endDate < date ? 0.6 : 1)
            }
            .transition(.push(from: .bottom))
        }
        if rows.isEmpty { Text("An open day").font(.headline) }
    }
}

struct WidgetWeekStrip: View {
    var days: [WidgetPresentation.Day]
    var style: WidgetStyle
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 3) {
            ForEach(days) { day in
                VStack(spacing: 4) {
                    Text(day.date, format: .dateTime.weekday(.narrow))
                        .font(style.italicDays ? .system(.caption2, design: .serif).italic() : .caption2)
                    Text(day.date, format: .dateTime.day())
                        .font(.system(.caption, design: style.numeralDesign)).monospacedDigit()
                        .foregroundStyle(day.today ? palette.accentOn : palette.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                        .background(day.today ? palette.accent : .clear, in: Capsule())
                        .widgetAccentable(day.today)
                    HStack(spacing: 2) {
                        ForEach(0..<min(3, day.eventCount), id: \.self) { _ in
                            Circle().fill(palette.accent).frame(width: 2, height: 2)
                        }
                    }
                    .frame(height: 3)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
