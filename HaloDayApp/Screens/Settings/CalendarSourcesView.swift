import SwiftUI

/// Which calendars feed the Orbit and widgets. An empty list means "all"; `["none"]` means the person turned every one off.
struct CalendarSourcesView: View {
    @Environment(HaloModel.self) private var model

    var body: some View {
        Form {
            if model.calendarService.isAuthorized {
                let calendars = model.calendarService.store.calendars(for: .event)
                ForEach(calendars, id: \.calendarIdentifier) { calendar in
                    Toggle(calendar.title, isOn: Binding(
                        get: { model.settings.enabledCalendarIDs.isEmpty || model.settings.enabledCalendarIDs.contains(calendar.calendarIdentifier) },
                        set: { enabled in
                            var ids = model.settings.enabledCalendarIDs.isEmpty ? calendars.map(\.calendarIdentifier) : model.settings.enabledCalendarIDs
                            ids.removeAll { $0 == "none" }
                            if enabled { ids.append(calendar.calendarIdentifier) } else { ids.removeAll { $0 == calendar.calendarIdentifier } }
                            model.settings.enabledCalendarIDs = ids.isEmpty ? ["none"] : (Set(ids) == Set(calendars.map(\.calendarIdentifier)) ? [] : ids)
                            model.saveSettings()
                        }
                    ))
                    .accessibilityIdentifier("calendar-source-\(calendar.calendarIdentifier)")
                }
            } else {
                Text("Connect your calendar to choose which ones Halo Day shows.")
                Button("Connect Calendar") { Task { await model.requestCalendar() } }
            }
        }
        .navigationTitle("Calendars")
    }
}
