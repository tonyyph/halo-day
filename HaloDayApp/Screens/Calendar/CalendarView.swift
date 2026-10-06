import SwiftUI

struct CalendarView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.haloNavigation) private var navigation
    @Environment(\.haloScreenshotMode) private var fixture
    @Environment(\.haloScreenshotScreen) private var screenshotScreen
    @Environment(\.haloReduceMotion) private var reduceMotion
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
                    .haloFont(.displayM)
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

            if mode != 1 { agenda }
        }
        .toolbar {
            Button { showSources = true } label: {
                Image(systemName: "line.3.horizontal.decrease")
            }
            .accessibilityLabel("Calendar sources")
        }
        .animation(Motion.resolve(Motion.smooth, reduceMotion: reduceMotion), value: mode)
        .animation(Motion.resolve(Motion.smooth, reduceMotion: reduceMotion), value: model.selectedDate)
        .onChange(of: model.selectedDate) { _, _ in if !fixture { Task { await model.refresh() } } }
        .onAppear { if screenshotScreen == "calendar" { mode = 2 } }
        .sheet(isPresented: $showSources) { sourcesSheet }
    }

    private var selectedBinding: Binding<Date> {
        Binding(get: { model.selectedDate }, set: { model.selectedDate = $0 })
    }

    private var dayView: some View {
        VStack(spacing: 16) {
            WeekStrip(selected: selectedBinding)
            CalendarDayPager(selected: selectedBinding, events: model.events) { event in
                navigation?.eventSource = "calendar-block-\(event.id)"
                model.selectedEvent = event
            }
        }
    }

    private var weekView: some View {
        CalendarWeekPager(selected: selectedBinding, events: model.events) { day in
            model.selectedDate = day
            mode = 0
        } onOpen: { event in
            navigation?.eventSource = "calendar-week-\(event.id)"
            model.selectedEvent = event
        }
    }

    private var monthView: some View {
        CalendarMonthPager(selected: selectedBinding, events: model.events)
            .accessibilityIdentifier("calendar-month-grid")
    }

    private var agenda: some View {
        let events = mode == 2 ? selectedDayEvents : shownEvents
        return VStack(alignment: .leading, spacing: 12) {
            Text(model.selectedDate, format: .dateTime.weekday(.wide).day().month(.wide))
                .haloFont(.displayS)

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
                            Button {
                                navigation?.eventSource = "calendar-row-\(event.id)"
                                model.selectedEvent = event
                            } label: {
                                AgendaRow(event: event)
                            }
                            .buttonStyle(PressableStyle())
                            .haloZoomSource("calendar-row-\(event.id)")
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

#Preview("Calendar · Month, Pearl Light") {
    CalendarView()
        .environment(HaloModel())
        .haloTheme(ThemeRegistry.theme("pearlHalo"))
        .environment(\.haloReferenceDate, Date(timeIntervalSince1970: 1_791_187_500))
}

#Preview("Calendar · Ruby Dark AX3") {
    CalendarView()
        .environment(HaloModel())
        .haloTheme(ThemeRegistry.theme("rubyGlass"))
        .environment(\.dynamicTypeSize, .accessibility3)
        .environment(\.haloReduceMotionOverride, true)
        .preferredColorScheme(.dark)
}
