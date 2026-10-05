import SwiftUI

struct CalendarDayPager: View {
    @Binding var selected: Date
    var events: [CalendarEvent]
    var onOpen: (CalendarEvent) -> Void
    @State private var pages: [Date] = []

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(pages, id: \.timeIntervalSinceReferenceDate) { day in
                    CalendarHourGrid(date: day, events: events, onOpen: onOpen)
                        .containerRelativeFrame(.horizontal)
                        .id(day)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: Binding<Date?>(
            get: { Calendar.current.startOfDay(for: selected) },
            set: { if let value = $0, !Calendar.current.isDate(value, inSameDayAs: selected) { selected = value } }
        ))
        .frame(height: 420)
        .onAppear { populate() }
        .onChange(of: selected) { _, value in
            if !pages.contains(Calendar.current.startOfDay(for: value)) { populate() }
        }
    }

    private func populate() {
        let start = Calendar.current.startOfDay(for: selected)
        pages = (-14...14).map { Calendar.current.date(byAdding: .day, value: $0, to: start)! }
    }
}

struct CalendarMonthPager: View {
    @Binding var selected: Date
    var events: [CalendarEvent]
    @State private var pages: [Date] = []
    @Environment(\.dynamicTypeSize) private var dynamicType

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(pages, id: \.timeIntervalSinceReferenceDate) { month in
                    let current = Calendar.current.isDate(month, equalTo: selected, toGranularity: .month)
                    HaloCard {
                        MiniMonthGrid(month: current ? selected : month, highlights: highlights(month)) { selected = $0 }
                    }
                    .containerRelativeFrame(.horizontal)
                    .id(month)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: Binding<Date?>(
            get: { Calendar.current.dateInterval(of: .month, for: selected)!.start },
            set: { if let value = $0, !Calendar.current.isDate(value, equalTo: selected, toGranularity: .month) { selected = value } }
        ))
        .frame(height: dynamicType.isAccessibilitySize ? 430 : 330)
        .onAppear { populate() }
        .onChange(of: selected) { _, value in
            if !pages.contains(Calendar.current.dateInterval(of: .month, for: value)!.start) { populate() }
        }
    }

    private func populate() {
        let start = Calendar.current.dateInterval(of: .month, for: selected)!.start
        pages = (-6...6).map { Calendar.current.date(byAdding: .month, value: $0, to: start)! }
    }

    private func highlights(_ month: Date) -> Set<Int> {
        let calendar = Calendar.current
        return Set(events.filter { calendar.isDate($0.startDate, equalTo: month, toGranularity: .month) }
            .map { calendar.component(.day, from: $0.startDate) })
    }
}

struct CalendarWeekOverview: View {
    struct Day: Identifiable { let date: Date; let events: [CalendarEvent]; var id: Date { date } }
    private let days: [Day]
    var onSelect: (Date) -> Void
    var onOpen: (CalendarEvent) -> Void
    @Environment(\.palette) private var palette

    init(date: Date, events: [CalendarEvent], onSelect: @escaping (Date) -> Void, onOpen: @escaping (CalendarEvent) -> Void) {
        self.onSelect = onSelect; self.onOpen = onOpen
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: date)!.start
        days = (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            return Day(date: day, events: events.filter { calendar.isDate($0.startDate, inSameDayAs: day) })
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            ForEach(days) { day in
                VStack(spacing: 8) {
                    Button { onSelect(day.date) } label: {
                        VStack(spacing: 4) {
                            Text(day.date, format: .dateTime.weekday(.narrow)).font(.caption)
                            Text(day.date, format: .dateTime.day()).font(.system(.headline, design: .rounded))
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(PressableStyle())
                    ForEach(day.events.prefix(4)) { event in
                        Button { onOpen(event) } label: {
                            Text(event.title).font(.caption2).lineLimit(3)
                                .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
                                .padding(4)
                                .background(PaletteResolver.eventAccent(event.accentColor).opacity(0.12),
                                            in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(PressableStyle())
                        .haloZoomSource("calendar-week-\(event.id)")
                    }
                    if day.events.count > 4 {
                        Button { onSelect(day.date) } label: {
                            Text("+\(day.events.count - 4)").font(.caption).frame(minHeight: 44)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(palette.ink)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

struct CalendarWeekPager: View {
    @Binding var selected: Date
    var events: [CalendarEvent]
    var onSelect: (Date) -> Void
    var onOpen: (CalendarEvent) -> Void
    @State private var pages: [Date] = []

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(pages, id: \.timeIntervalSinceReferenceDate) { date in
                    CalendarWeekOverview(date: date, events: events, onSelect: onSelect, onOpen: onOpen)
                        .containerRelativeFrame(.horizontal)
                        .id(date)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: Binding<Date?>(
            get: { Calendar.current.dateInterval(of: .weekOfYear, for: selected)!.start },
            set: { if let value = $0, !Calendar.current.isDate(value, equalTo: selected, toGranularity: .weekOfYear) { selected = value } }
        ))
        .frame(height: 380)
        .onAppear {
            let start = Calendar.current.dateInterval(of: .weekOfYear, for: selected)!.start
            pages = (-6...6).map { Calendar.current.date(byAdding: .weekOfYear, value: $0, to: start)! }
        }
    }
}

#Preview("Calendar pagers · Pearl") {
    @Previewable @State var date = Date.now
    DesignPreview { CalendarMonthPager(selected: $date, events: MockData.events()) }
}

#Preview("Calendar pagers · Gold Empty AX3") {
    @Previewable @State var date = Date.now
    DesignPreview(themeID: "midnightGold", scheme: .dark, accessibility: true, reduceMotion: true) {
        CalendarWeekPager(selected: $date, events: [], onSelect: { _ in }, onOpen: { _ in })
    }
}
