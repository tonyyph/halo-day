import SwiftUI
import WidgetKit

struct SettingsView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @Environment(\.haloToasts) private var toasts
    @Environment(\.haloReferenceDate) private var referenceDate
    @State private var manageSubscriptions = false
    @State private var redeemingCode = false
    @State private var locating = false
    @State private var locationMessage: String?
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "3"

    var body: some View {
        @Bindable var model = model
        let sky = SkyEngine.state(sky: model.settings.skyID, at: referenceDate ?? .now, coordinate: model.skyCoordinate)
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

                if model.purchases.isPremium, let until = model.purchases.premiumUntil {
                    Text(model.purchases.premiumFromCode
                         ? "From your code, until \(until.formatted(date: .abbreviated, time: .shortened))"
                         : "Renews or ends \(until.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .accessibilityIdentifier("settings-premium-until")
                }
                Button { Task { await model.purchases.restore() } } label: {
                    SettingsLabel(title: "Restore purchases", symbol: "arrow.clockwise")
                }
                Button { redeemingCode = true } label: {
                    SettingsLabel(title: "Redeem code", symbol: "giftcard")
                }
                .accessibilityIdentifier("settings-redeem")
                .offerCodeRedemption(isPresented: $redeemingCode) { _ in
                    Task { await model.purchases.refreshEntitlements() }
                }
                Button { manageSubscriptions = true } label: {
                    SettingsLabel(title: "Manage subscription", symbol: "creditcard")
                }
            }
            .listRowBackground(sky.mid.color)

            if model.purchases.isTestEnvironment {
                // For QC on TestFlight: what StoreKit actually returned on this device.
                Section {
                    LabeledContent("Environment", value: "Sandbox / TestFlight")
                    LabeledContent("Plans loaded", value: "\(model.purchases.products.count) of \(PurchaseService.productIDs.count)")
                    ForEach(PurchaseService.productIDs, id: \.self) { id in
                        LabeledContent(id, value: model.purchases.products.first { $0.id == id }?.displayPrice ?? "—")
                            .font(.caption)
                    }
                    LabeledContent("Premium", value: model.purchases.isPremium ? "Active" : "Off")
                    if let until = model.purchases.premiumUntil {
                        LabeledContent("Until", value: until.formatted(date: .abbreviated, time: .shortened))
                    }
                    Button("Reload plans") { Task { await model.purchases.loadProducts(); await model.purchases.refreshEntitlements() } }
                } header: {
                    Text(verbatim: "StoreKit (QC)")
                } footer: {
                    Text(verbatim: "Only in TestFlight and development builds. 0 plans loaded means the products are missing or not Ready to Submit in App Store Connect, or the Paid Apps Agreement isn't active.")
                }
                .listRowBackground(sky.mid.color)
            }

            Section {
                TextField("Your first name", text: $model.settings.firstName)
                    .onSubmit { model.persist() }
            } header: {
                Text("Profile")
            } footer: {
                Text("Used only for your greeting.")
            }
            .listRowBackground(sky.mid.color)

            Section {
                NavigationLink { SkyPickerView() } label: {
                    SettingsLabel(title: "Sky", symbol: "sun.horizon")
                }
                .accessibilityIdentifier("settings-sky")
                Toggle(isOn: Binding(get: { locating || model.settings.approxCoordinate != nil },
                                     set: { enabled in
                                         guard !locating else { return }
                                         locating = enabled
                                         locationMessage = nil
                                         Task {
                                             locationMessage = await model.useLocationForSky(enabled)
                                             locating = false
                                         }
                                     })) {
                    HStack {
                        SettingsLabel(title: "Match the sky to my location", symbol: "location")
                        if locating { ProgressView().padding(.leading, 4) }
                    }
                }
                .disabled(locating)
                .accessibilityIdentifier("settings-location")
                if let locationMessage {
                    Text(locationMessage).font(.footnote).accessibilityIdentifier("settings-location-message")
                }
                Toggle(isOn: $model.settings.haptics) {
                    SettingsLabel(title: "Haptics", symbol: "waveform")
                }
            } header: {
                Text("Appearance")
            } footer: {
                Text("Rounded to about 10 km and kept on this iPhone.")
            }
            .listRowBackground(sky.mid.color)

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
            .listRowBackground(sky.mid.color)

            Section("Reminders") {
                Button { Task { await model.requestNotifications() } } label: {
                    SettingsLabel(title: "Allow reminders", symbol: "bell")
                }
                Picker("Before events", selection: $model.settings.eventReminderMinutes) {
                    Text("Off").tag(0)
                    ForEach([5, 10, 15, 30], id: \.self) { Text("\($0) min").tag($0) }
                }
            }
            .listRowBackground(sky.mid.color)

            Section("Live Activities") {
                Toggle(isOn: $model.settings.liveActivities) {
                    SettingsLabel(title: "Focus sessions on Lock Screen", symbol: "timer")
                }
                Text(LocalizedStringKey(model.activities.enabled
                    ? "Live Activities are available"
                    : "Live Activities are turned off for Halo Day in iOS Settings."))
                    .haloFont(.footnote)
                    .opacity(SkyEngine.secondaryOpacity)
            }
            .listRowBackground(sky.mid.color)

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
            .listRowBackground(sky.mid.color)

            Section("About") {
                Text("Your calendar never leaves your iPhone. Halo Day has no accounts, no tracking, and no servers.")
                    .haloFont(.footnote)
                NavigationLink { LicensesView() } label: { SettingsLabel(title: "Licenses", symbol: "doc.text") }
                Text("Version \(version) (\(build))")
                    .haloFont(.caption)
                    .opacity(SkyEngine.secondaryOpacity)
            }
            .listRowBackground(sky.mid.color)
        }
        .scrollContentBackground(.hidden)
        .background { SkyBackground(state: sky) }
        // Toggles need a colour that differs from the thumb on every sky; text tint stays the ink.
        .tint(OrbitPalette.ritualColor(sky: sky))
        .environment(\.colorScheme, sky.ink == .light ? .dark : .light)
        .toolbarColorScheme(sky.ink == .light ? .dark : .light, for: .navigationBar)
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

#Preview("Settings") {
    NavigationStack { SettingsView() }.environment(HaloModel())
}

#Preview("Settings · AX3") {
    NavigationStack { SettingsView() }.environment(HaloModel())
        .environment(\.dynamicTypeSize, .accessibility3)
}
