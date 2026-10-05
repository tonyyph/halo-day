import SwiftUI

struct AgendaTimeline: View {
    private let timed: [CalendarEvent]
    private let allDay: [CalendarEvent]
    var date: Date
    var fixedDate: Date?
    var onOpen: (CalendarEvent, String) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicType

    init(events: [CalendarEvent], date: Date, fixedDate: Date?, onOpen: @escaping (CalendarEvent, String) -> Void) {
        timed = Array(events.filter { !$0.isAllDay }.prefix(6))
        allDay = events.filter(\.isAllDay)
        self.date = date; self.fixedDate = fixedDate; self.onOpen = onOpen
    }

    var body: some View {
        HaloCard {
            VStack(spacing: 12) {
                if !allDay.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(allDay) { event in
                                HaloChip(title: event.title, selected: false) { onOpen(event, "today-row-\(event.id)") }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
                VStack(spacing: 0) {
                    ForEach(timed) { event in
                        Button { onOpen(event, "today-row-\(event.id)") } label: {
                            AgendaRow(event: event, date: date)
                                .frame(minHeight: 64)
                        }
                        .buttonStyle(PressableStyle())
                        .haloZoomSource("today-row-\(event.id)")
                    }
                }
                .overlay(alignment: .topLeading) {
                    if !dynamicType.isAccessibilitySize && !timed.isEmpty {
                        AgendaNowRail(events: timed, referenceDate: fixedDate)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
    }
}

private struct AgendaNowRail: View {
    struct Anchor: Sendable { let date: Date; let y: CGFloat }
    private let anchors: [Anchor]
    var referenceDate: Date?
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion

    init(events: [CalendarEvent], referenceDate: Date?) {
        anchors = events.enumerated().flatMap { index, event in
            [Anchor(date: event.startDate, y: CGFloat(index) * 64 + 8),
             Anchor(date: event.endDate, y: CGFloat(index) * 64 + 56)]
        }
        self.referenceDate = referenceDate
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let date = referenceDate ?? context.date
            let y = Self.position(at: date, anchors: anchors)
            HStack(spacing: 0) {
                Circle().fill(palette.accent).frame(width: 6, height: 6)
                Rectangle().fill(palette.accent.opacity(0.6)).frame(width: 14, height: 1)
            }
            .shadow(color: palette.accent.opacity(0.3), radius: 4)
            .padding(.leading, 71)
            .offset(y: y ?? 0)
            .opacity(y == nil ? 0 : 1)
            .animation(Motion.resolve(Motion.smooth, reduceMotion: reduceMotion), value: y)
        }
        .accessibilityHidden(true)
    }

    private nonisolated static func position(at date: Date, anchors: [Anchor]) -> CGFloat? {
        guard let first = anchors.first, let last = anchors.last, date >= first.date && date <= last.date else { return nil }
        for index in 1..<anchors.count {
            let a = anchors[index - 1], b = anchors[index]
            if date <= b.date {
                let fraction = max(0, min(1, date.timeIntervalSince(a.date) / max(1, b.date.timeIntervalSince(a.date))))
                return a.y + (b.y - a.y) * fraction
            }
        }
        return last.y
    }
}

#Preview("Agenda · Light") {
    DesignPreview { AgendaTimeline(events: MockData.events(), date: .now, fixedDate: nil, onOpen: { _, _ in }) }
}

#Preview("Agenda · Ruby Dark Empty AX3") {
    DesignPreview(themeID: "rubyGlass", scheme: .dark, accessibility: true, reduceMotion: true) {
        AgendaTimeline(events: [], date: .now, fixedDate: nil, onOpen: { _, _ in })
    }
}
