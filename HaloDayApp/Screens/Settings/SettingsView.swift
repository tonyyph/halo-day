import SwiftUI
import WidgetKit

struct SettingsView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @Environment(\.haloToasts) private var toasts
    @State private var manageSubscriptions = false
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "3"

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Button {
                    model.showSettings = false
                    model.showPaywall = true
                } label: {
                    PremiumStatusRow(premium: model.purchases.isPremium)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(model.purchases.isPremium ? Text("Halo Day Premium") : Text("Upgrade to Premium"))
                .accessibilityIdentifier("settings-upgrade")

                Button { Task { await model.purchases.restore() } } label: {
                    SettingsLabel(title: "Restore purchases", symbol: "arrow.clockwise")
                }
                Button { manageSubscriptions = true } label: {
                    SettingsLabel(title: "Manage subscription", symbol: "creditcard")
                }
            }
            .listRowBackground(palette.surface)

            Section {
                TextField("Your first name", text: $model.settings.firstName)
                    .onSubmit { model.persist() }
            } header: {
                Text("Profile")
            } footer: {
                Text("Used only for your greeting.")
            }
            .listRowBackground(palette.surface)

            Section("Appearance") {
                NavigationLink {
                    ThemesView()
                } label: {
                    SettingsLabel(title: "App theme", symbol: "paintpalette")
                }
                .accessibilityIdentifier("settings-theme")
                Toggle(isOn: $model.settings.haptics) {
                    SettingsLabel(title: "Haptics", symbol: "waveform")
                }
            }
            .listRowBackground(palette.surface)

            Section {
                Stepper(value: $model.settings.dayStartHour, in: 0...max(0, model.settings.dayEndHour - 1)) {
                    Label { Text("Starts at \(model.settings.dayStartHour):00") } icon: { SettingsGlyph(symbol: "sunrise") }
                }
                Stepper(value: $model.settings.dayEndHour, in: min(23, model.settings.dayStartHour + 1)...24) {
                    Label { Text("Ends at \(model.settings.dayEndHour):00") } icon: { SettingsGlyph(symbol: "sunset") }
                }
            } header: {
                Text("Your day")
            } footer: {
                Text("Day progress is measured between these times.")
            }
            .listRowBackground(palette.surface)

            Section("Calendar") {
                SettingsLabel(
                    title: model.calendarService.isAuthorized ? "Calendar connected" : "Calendar access is off",
                    symbol: model.calendarService.isAuthorized ? "calendar.badge.checkmark" : "calendar"
                )
                Button("Connect Calendar") { Task { await model.requestCalendar() } }
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                NavigationLink { CalendarSourcesView() } label: {
                    SettingsLabel(title: "Calendars", symbol: "list.bullet")
                }
                .accessibilityIdentifier("settings-calendars")
                Toggle("Include all-day events", isOn: $model.settings.includeAllDay)
            }
            .listRowBackground(palette.surface)

            Section("Reminders") {
                Button { Task { await model.requestNotifications() } } label: {
                    SettingsLabel(title: "Allow reminders", symbol: "bell")
                }
                Picker("Before events", selection: $model.settings.eventReminderMinutes) {
                    Text("Off").tag(0)
                    ForEach([5, 10, 15, 30], id: \.self) { Text("\($0) min").tag($0) }
                }
            }
            .listRowBackground(palette.surface)

            Section("Live Activities") {
                Toggle(isOn: $model.settings.liveActivities) {
                    SettingsLabel(title: "Focus sessions on Lock Screen", symbol: "timer")
                }
                Text(LocalizedStringKey(model.activities.enabled
                    ? "Live Activities are available"
                    : "Live Activities are turned off for Halo Day in iOS Settings."))
                    .haloFont(.footnote)
                    .foregroundStyle(palette.ink2)
            }
            .listRowBackground(palette.surface)

            Section("Widgets") {
                Button {
                    model.showSettings = false
                    model.showGuide = true
                } label: {
                    SettingsLabel(title: "How to add widgets", symbol: "iphone")
                }
                Button {
                    Task {
                        await model.refresh()
                        toasts?.show("Widgets refreshed")
                    }
                } label: {
                    SettingsLabel(title: "Refresh widgets now", symbol: "arrow.triangle.2.circlepath")
                }
            }
            .listRowBackground(palette.surface)

            Section("About") {
                Text("Your calendar never leaves your iPhone. Halo Day has no accounts, no tracking, and no servers.")
                    .haloFont(.footnote)
                Text("Version \(version) (\(build))")
                    .haloFont(.caption)
                    .foregroundStyle(palette.ink2)
            }
            .listRowBackground(palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background { ThemeBackground() }
        .tint(palette.accentInk)
        .navigationTitle("Settings")
        .toolbar {
            Button("Done") {
                model.persist()
                Task { await model.refresh() }
                dismiss()
            }
        }
        .onDisappear { model.persist() }
        .manageSubscriptionsSheet(isPresented: $manageSubscriptions)
    }
}

#Preview("Settings · Pearl") {
    NavigationStack { SettingsView() }.environment(HaloModel())
        .haloTheme(ThemeRegistry.theme("pearlHalo"))
}

#Preview("Settings · Ruby Dark AX3") {
    NavigationStack { SettingsView() }.environment(HaloModel())
        .haloTheme(ThemeRegistry.theme("rubyGlass"))
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility3)
        .environment(\.haloReduceMotionOverride, true)
}
