import SwiftUI
import WidgetKit

struct SettingsView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var manageSubscriptions = false
    var body: some View {
        @Bindable var model = model
        Form {
            Section("Premium") {
                Button(model.purchases.isPremium ? "Halo Day Premium" : "Upgrade to Premium") { model.showSettings = false; model.showPaywall = true }
                Button("Restore purchases") { Task { await model.purchases.restore() } }
                Button("Manage subscription") { manageSubscriptions = true }
            }
            Section { TextField("Your first name", text: $model.settings.firstName).onSubmit { model.persist() } } header: { Text("Profile") } footer: { Text("Used only for your greeting.") }
            Section("Appearance") {
                NavigationLink("App theme") { ThemesView() }
                Toggle("Haptics", isOn: $model.settings.haptics)
            }
            Section { Stepper("Starts at \(model.settings.dayStartHour):00", value: $model.settings.dayStartHour, in: 0...max(0, model.settings.dayEndHour - 1)); Stepper("Ends at \(model.settings.dayEndHour):00", value: $model.settings.dayEndHour, in: min(23, model.settings.dayStartHour + 1)...24) } header: { Text("Your day") } footer: { Text("Day progress is measured between these times.") }
            Section("Calendar") {
                Text(model.calendarService.isAuthorized ? "Calendar connected" : "Calendar access is off")
                Button("Connect Calendar") { Task { await model.requestCalendar() } }
                Button("Open Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                Toggle("Include all-day events", isOn: $model.settings.includeAllDay)
            }
            Section("Reminders") {
                Button("Allow reminders") { Task { await model.requestNotifications() } }
                Picker("Before events", selection: $model.settings.eventReminderMinutes) { Text("Off").tag(0); ForEach([5, 10, 15, 30], id: \.self) { Text("\($0) min").tag($0) } }
            }
            Section("Live Activities") { Toggle("Focus sessions on Lock Screen", isOn: $model.settings.liveActivities); Text(model.activities.enabled ? "Live Activities are available" : "Live Activities are turned off for Halo Day in iOS Settings.").font(.caption) }
            Section("Widgets") {
                Button("How to add widgets") { model.showSettings = false; model.showGuide = true }
                Button("Refresh widgets now") { Task { await model.refresh() } }
            }
            Section("About") {
                Text("Your calendar never leaves your iPhone. Halo Day has no accounts, no tracking, and no servers.")
                Text("Version 1.0 · MVP").font(.caption)
            }
        }.navigationTitle("Settings").toolbar { Button("Done") { model.persist(); Task { await model.refresh() }; dismiss() } }
            .onDisappear { model.persist() }
            .manageSubscriptionsSheet(isPresented: $manageSubscriptions)
    }
}
