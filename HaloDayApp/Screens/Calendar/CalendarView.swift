import SwiftUI

struct CalendarView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mode = 0
    @State private var showSources = false

    private var interval: DateInterval {
        let unit: Calendar.Component = mode == 1 ? .weekOfYear : mode == 2 ? .month : .day
        return Calendar.current.dateInterval(of: unit, for: model.selectedDate)!
    }

    private var shownEvents: [CalendarEvent] {
        model.events.filter { $0.startDate < interval.end && $0.endDate > interval.start }
    }

    private var selectedDayEvents: [CalendarEvent] {
        let day = Calendar.current.dateInterval(of: .day, for: model.selectedDate)!
        return model.events.filter { $0.startDate < day.end && $0.endDate > day.start }
    }

    var body: some View {
        @Bindable var model = model
        HaloScreen {
            SectionTitle(
                title: "Calendar",
                subtitle: model.isSample
                    ? "Sample events. Your calendar stays on your iPhone."
                    : "A little clarity for the days ahead."
            )

            HaloSegmented(
                options: [(0, "Day"), (1, "Week"), (2, "Month")],
                selection: $mode
            )

            HStack {
                Button { shift(-1) } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Previous")
                Spacer()
                Text(model.selectedDate, format: .dateTime.month(.wide).year())
                    .font(HaloFont.displayM)
                    .contentTransition(.numericText())
                Spacer()
                Button { shift(1) } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Next")
            }

            if mode == 2 {
                monthView
            } else if mode == 1 {
                weekView
            } else {
                dayView
            }

            agenda
        }
        .toolbar {
            Button { showSources = true } label: {
                Image(systemName: "line.3.horizontal.decrease")
            }
            .accessibilityLabel("Calendar sources")
        }
        .animation(Motion.resolve(Motion.smooth, reduceMotion: reduceMotion), value: mode)
        .animation(Motion.resolve(Motion.smooth, reduceMotion: reduceMotion), value: model.selectedDate)
        .onChange(of: model.selectedDate) { _, _ in Task { await model.refresh() } }
        .sheet(isPresented: $showSources) { sourcesSheet }
    }

    private var dayView: some View {
        HaloCard(variant: .plain) {
            WeekStrip(selected: Binding(
                get: { model.selectedDate },
                set: { model.selectedDate = $0 }
            ))
        }
    }

    private var weekView: some View {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: model.selectedDate)!.start
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(0..<7, id: \.self) { offset in
                let day = calendar.date(byAdding: .day, value: offset, to: start)!
                let count = shownEvents.filter { calendar.isDate($0.startDate, inSameDayAs: day) }.count
                Button {
                    model.selectedDate = day
                    mode = 0
                } label: {
                    VStack(spacing: 8) {
                        Text(day, format: .dateTime.weekday(.narrow)).font(HaloFont.caption)
                        Text(day, format: .dateTime.day()).font(HaloFont.numericM)
                        Circle()
                            .fill(count > 0 ? palette.accent : .clear)
                            .frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity, minHeight: 78)
                    .background(
                        calendar.isDate(day, inSameDayAs: model.selectedDate)
                            ? palette.accentSoft : palette.surface,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(Text(day, format: .dateTime.weekday().month().day()))
            }
        }
    }

    private var monthView: some View {
        HaloCard {
            MiniMonthGrid(
                month: model.selectedDate,
                highlights: Set(shownEvents.map { Calendar.current.component(.day, from: $0.startDate) })
            ) { date in
                model.selectedDate = date
            }
        }
    }

    private var agenda: some View {
        let events = mode == 2 ? selectedDayEvents : shownEvents
        return VStack(alignment: .leading, spacing: 12) {
            Text(model.selectedDate, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(HaloFont.displayS)

            if events.isEmpty {
                EmptyState(
                    icon: "calendar",
                    title: "An open day",
                    message: "Nothing scheduled. A rare, open day."
                )
            } else {
                HaloCard {
                    VStack(spacing: 0) {
                        ForEach(events) { event in
                            Button { model.selectedEvent = event } label: {
                                AgendaRow(event: event)
                            }
                            .buttonStyle(PressableStyle())
                            if event.id != events.last?.id { Divider().padding(.leading, 80) }
                        }
                    }
                }
            }
        }
    }

    private var sourcesSheet: some View {
        NavigationStack {
            Form {
                if model.calendarService.isAuthorized {
                    ForEach(
                        model.calendarService.store.calendars(for: .event),
                        id: \.calendarIdentifier
                    ) { calendar in
                        Toggle(calendar.title, isOn: Binding(
                            get: {
                                model.settings.enabledCalendarIDs.isEmpty ||
                                    model.settings.enabledCalendarIDs.contains(calendar.calendarIdentifier)
                            },
                            set: { enabled in
                                if model.settings.enabledCalendarIDs.isEmpty {
                                    model.settings.enabledCalendarIDs = model.calendarService.store
                                        .calendars(for: .event).map(\.calendarIdentifier)
                                }
                                if enabled {
                                    model.settings.enabledCalendarIDs.append(calendar.calendarIdentifier)
                                } else {
                                    model.settings.enabledCalendarIDs.removeAll {
                                        $0 == calendar.calendarIdentifier
                                    }
                                }
                                if model.settings.enabledCalendarIDs.isEmpty {
                                    model.settings.enabledCalendarIDs = ["none"]
                                }
                                model.saveSettings()
                            }
                        ))
                    }
                } else {
                    Button("Connect Calendar") { Task { await model.requestCalendar() } }
                }
            }
            .navigationTitle("Calendar sources")
            .toolbar { Button("Done") { showSources = false } }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(32)
    }

    private func shift(_ amount: Int) {
        model.selectedDate = Calendar.current.date(
            byAdding: mode == 2 ? .month : mode == 1 ? .weekOfYear : .day,
            value: amount,
            to: model.selectedDate
        )!
    }
}

struct EventDetailView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var event: CalendarEvent

    var body: some View {
        HaloScreen {
            SectionTitle(title: event.title)
            HaloCard {
                VStack(alignment: .leading, spacing: HaloTokens.Space.card) {
                    Label(event.calendarName, systemImage: "calendar")
                    Text(event.startDate, format: .dateTime.weekday().month().day().hour().minute())
                    Text(event.endDate, format: .dateTime.hour().minute())
                        .foregroundStyle(.secondary)
                    if let location = event.location {
                        Label(location, systemImage: "mappin")
                    }
                    if event.source == "sample" {
                        Text("Sample event").font(HaloFont.caption)
                    }
                }
            }
            Button("Count down to this") {
                Task { await model.countDown(event) }
            }
            .buttonStyle(HaloButtonStyle())
            Text("Live countdowns can begin in the hour before an event.")
                .font(HaloFont.caption)
                .foregroundStyle(.secondary)
        }
        .toolbar { Button("Done") { dismiss() } }
    }
}
