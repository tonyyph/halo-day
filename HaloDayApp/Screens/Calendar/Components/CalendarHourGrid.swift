import SwiftUI

struct CalendarDayLayout {
    struct Placement: Identifiable {
        let event: CalendarEvent
        let column: Int
        var columns: Int
        let y: CGFloat
        let height: CGFloat
        var id: String { event.id }
    }
    let placements: [Placement]
    let hours: [Date]

    init(date: Date, events: [CalendarEvent]) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        hours = (0..<24).map { calendar.date(byAdding: .hour, value: $0, to: start)! }
        let values = events.filter { !$0.isAllDay && $0.startDate < end && $0.endDate > start }
            .sorted { $0.startDate < $1.startDate }
        var output: [Placement] = []
        var cluster: [Placement] = []
        var columnEnds: [Date] = []
        var clusterEnd = start
        func finish() {
            for var value in cluster { value.columns = max(1, columnEnds.count); output.append(value) }
            cluster = []; columnEnds = []
        }
        for event in values {
            if event.startDate >= clusterEnd { finish() }
            let column = columnEnds.firstIndex(where: { $0 <= event.startDate }) ?? columnEnds.count
            if column == columnEnds.count { columnEnds.append(event.endDate) }
            else { columnEnds[column] = event.endDate }
            clusterEnd = max(clusterEnd, event.endDate)
            let y = max(start, event.startDate).timeIntervalSince(start) / 3600 * 56
            let height = min(end, event.endDate).timeIntervalSince(max(start, event.startDate)) / 3600 * 56
            cluster.append(Placement(event: event, column: column, columns: 1, y: y, height: max(28, height)))
        }
        finish()
        placements = output
    }
}

struct CalendarHourGrid: View {
    var date: Date
    var onOpen: (CalendarEvent) -> Void
    private let layout: CalendarDayLayout
    @Environment(\.palette) private var palette
    @Environment(\.haloReferenceDate) private var referenceDate
    @State private var hour: Int?

    init(date: Date, events: [CalendarEvent], onOpen: @escaping (CalendarEvent) -> Void) {
        self.date = date; self.onOpen = onOpen
        layout = CalendarDayLayout(date: date, events: events)
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                ForEach(layout.hours.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 8) {
                        Text(layout.hours[index], style: .time)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(palette.ink3)
                            .frame(width: 52, alignment: .trailing)
                        Rectangle().fill(palette.hairline).frame(height: 0.5).padding(.top, 6)
                    }
                    .frame(height: 56, alignment: .top)
                    .id(index)
                }
            }
            .scrollTargetLayout()
            .overlay(alignment: .topLeading) {
                GeometryReader { proxy in
                    ForEach(layout.placements) { placement in
                        let width = max(0, (proxy.size.width - 64) / CGFloat(placement.columns) - 4)
                        CalendarEventBlock(placement: placement) { onOpen(placement.event) }
                            .frame(width: width, height: placement.height, alignment: .topLeading)
                            .offset(x: 64 + CGFloat(placement.column) * (width + 4), y: placement.y)
                            .haloZoomSource("calendar-block-\(placement.id)")
                    }
                    CalendarNowLine(day: date, referenceDate: referenceDate).allowsHitTesting(false)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .scrollPosition(id: $hour, anchor: .top)
        .onAppear { hour = max(0, Calendar.current.component(.hour, from: referenceDate ?? .now) - 1) }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

private struct CalendarEventBlock: View {
    var placement: CalendarDayLayout.Placement
    var onOpen: () -> Void

    var body: some View {
        let color = PaletteResolver.eventAccent(placement.event.accentColor)
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 6) {
                Capsule().fill(color).frame(width: 3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(placement.event.title).font(.caption.weight(.semibold)).lineLimit(placement.height > 55 ? 2 : 1)
                    if placement.height > 40 {
                        Text(placement.event.startDate, style: .time).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(Text(placement.event.title))
    }
}

private struct CalendarNowLine: View {
    var day: Date
    var referenceDate: Date?
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = referenceDate ?? context.date
            let visible = Calendar.current.isDate(day, inSameDayAs: now)
            let y = now.timeIntervalSince(Calendar.current.startOfDay(for: now)) / 3600 * 56
            HStack(spacing: 0) {
                Circle().fill(palette.accent).frame(width: 6, height: 6)
                Rectangle().fill(palette.accent).frame(height: 1)
            }
            .shadow(color: palette.accent.opacity(0.3), radius: 4)
            .padding(.leading, 58)
            .offset(y: y)
            .opacity(visible ? 1 : 0)
            .animation(Motion.resolve(Motion.smooth, reduceMotion: reduceMotion), value: y)
        }
        .accessibilityHidden(true)
    }
}

#Preview("Hour grid · Pearl") {
    DesignPreview { CalendarHourGrid(date: .now, events: MockData.events(), onOpen: { _ in }).frame(height: 420) }
}

#Preview("Hour grid · Ruby Dark Empty AX3") {
    DesignPreview(themeID: "rubyGlass", scheme: .dark, accessibility: true, reduceMotion: true) {
        CalendarHourGrid(date: .now, events: [], onOpen: { _ in }).frame(height: 420)
    }
}
