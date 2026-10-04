import SwiftUI

struct CalendarView: View {
    @Environment(HaloModel.self) private var model
    @State private var mode = 0
    @State private var showSources = false
    private var shownEvents: [CalendarEvent] {
        let unit: Calendar.Component = mode == 1 ? .weekOfYear : mode == 2 ? .month : .day
        let interval = Calendar.current.dateInterval(of: unit, for: model.selectedDate)!
        return model.events.filter { $0.startDate < interval.end && $0.endDate > interval.start }
    }
    var body: some View {
        @Bindable var model = model
        HaloScreen {
            SectionTitle(title: "Calendar", subtitle: model.isSample ? "Sample events. Your calendar stays on your iPhone." : "A little clarity for the days ahead.")
            Picker("View", selection: $mode) { Text("Day").tag(0); Text("Week").tag(1); Text("Month").tag(2) }.pickerStyle(.segmented)
            HStack {
                Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("Previous")
                Spacer()
                Text(model.selectedDate, format: .dateTime.month(.wide).year()).font(HaloTokens.title)
                Spacer()
                Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.accessibilityLabel("Next")
            }
            HaloCard { WeekStrip(selected: $model.selectedDate) }
            if mode == 2 {
                HaloCard {
                    MiniMonthGrid(month: model.selectedDate, highlights: Set(shownEvents.map { Calendar.current.component(.day, from: $0.startDate) })) { date in model.selectedDate = date; mode = 0 }
                }
            }
            if shownEvents.isEmpty { EmptyState(icon: "calendar", title: "An open day", message: "Nothing scheduled. A rare, open day.") }
            else {
                ForEach(shownEvents) { event in
                    Button { model.selectedEvent = event } label: {
                        HaloCard {
                            VStack(alignment: .leading, spacing: HaloTokens.Space.tiny) {
                                if mode != 0 { Text(event.startDate, format: .dateTime.weekday().day()).font(.caption).foregroundStyle(.secondary) }
                                AgendaRow(event: event)
                            }
                        }
                    }.buttonStyle(.plain)
                }
            }
        }.toolbar { Button { showSources = true } label: { Image(systemName: "line.3.horizontal.decrease") }.accessibilityLabel("Calendar sources") }
            .onChange(of: model.selectedDate) { _, _ in Task { await model.refresh() } }
            .sheet(isPresented: $showSources) {
                NavigationStack {
                    Form {
                        if model.calendarService.isAuthorized {
                            ForEach(model.calendarService.store.calendars(for: .event), id: \.calendarIdentifier) { calendar in
                                Toggle(calendar.title, isOn: Binding(get: { model.settings.enabledCalendarIDs.isEmpty || model.settings.enabledCalendarIDs.contains(calendar.calendarIdentifier) }, set: { enabled in
                                    if model.settings.enabledCalendarIDs.isEmpty { model.settings.enabledCalendarIDs = model.calendarService.store.calendars(for: .event).map(\.calendarIdentifier) }
                                    if enabled { model.settings.enabledCalendarIDs.append(calendar.calendarIdentifier) }
                                    else { model.settings.enabledCalendarIDs.removeAll { $0 == calendar.calendarIdentifier } }
                                    // Empty selection uses a sentinel to distinguish it from "all".
                                    if model.settings.enabledCalendarIDs.isEmpty { model.settings.enabledCalendarIDs = ["none"] }
                                    model.saveSettings()
                                }))
                            }
                        } else { Button("Connect Calendar") { Task { await model.requestCalendar() } } }
                    }.navigationTitle("Calendar sources").toolbar { Button("Done") { showSources = false } }
                }
            }
    }
    private func shift(_ amount: Int) { model.selectedDate = Calendar.current.date(byAdding: mode == 2 ? .month : mode == 1 ? .weekOfYear : .day, value: amount, to: model.selectedDate)! }
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
                    Text(event.endDate, format: .dateTime.hour().minute()).foregroundStyle(.secondary)
                    if let location = event.location { Label(location, systemImage: "mappin") }
                    if event.source == "sample" { Text("Sample event").font(.caption) }
                }
            }
            Button("Count down to this") { Task { await model.countDown(event) } }.buttonStyle(HaloButtonStyle())
            Text("Live countdowns can begin in the hour before an event.").font(.caption).foregroundStyle(.secondary)
        }.toolbar { Button("Done") { dismiss() } }
    }
}
