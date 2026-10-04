import SwiftUI
import WidgetKit

struct StudioView: View {
    @Environment(HaloModel.self) private var model
    @State private var preset = WidgetPreset(name: "My Halo")
    @State private var saved = false
    @State private var showCountdown = false
    @State private var countdownTitle = ""
    @State private var countdownDate = Date.now.addingTimeInterval(86400 * 14)
    var body: some View {
        HaloScreen {
            SectionTitle(title: "Widget Studio", subtitle: "A little window into your day.")
            PhonePreview(preset: preset, events: model.todayEvents, habits: model.habits, focus: model.focus, countdown: model.countdowns.first, sample: model.isSample).frame(maxWidth: .infinity)
            Text(preset.widgetFamily.isAccessory ? "Lock Screen colors follow your wallpaper. This preview shows the layout." : "Home Screen widgets show your theme in full color.").font(.caption).foregroundStyle(.secondary)
            HaloCard {
                VStack(alignment: .leading, spacing: HaloTokens.Space.card) {
                    Text("Widget size").font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: HaloTokens.Space.small) {
                        ForEach(WidgetSize.allCases) { size in
                            Button { preset.widgetFamily = size; model.haptic() } label: {
                                Text(LocalizedStringKey(size.rawValue.capitalized)).font(.caption).frame(maxWidth: .infinity, minHeight: 44)
                                    .background(preset.widgetFamily == size ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(Color.primary.opacity(0.04)), in: RoundedRectangle(cornerRadius: HaloTokens.Radius.small))
                            }.buttonStyle(.plain)
                        }
                    }
                    Picker("Widget type", selection: $preset.widgetType) { ForEach(WidgetType.allCases) { Text(LocalizedStringKey($0.title)).tag($0) } }
                    Picker("Theme", selection: $preset.themeId) { ForEach(ThemeRegistry.all) { Text($0.name).tag($0.id) } }
                    TextField("Preset name", text: $preset.name).textFieldStyle(.roundedBorder)
                    NavigationLink { ThemesView() } label: { Label("Explore all themes", systemImage: "paintpalette") }
                    if preset.widgetType == .countdown {
                        Button("Add countdown") { showCountdown = true }
                    }
                }
            }
            Button(saved ? "Saved beautifully" : "Save preset") {
                preset.updatedAt = .now
                if model.savePreset(preset) { saved = true; preset.id = UUID() }
            }.buttonStyle(HaloButtonStyle()).disabled(preset.name.trimmingCharacters(in: .whitespaces).isEmpty)
            Button { model.showGuide = true } label: { Label("How to add to Lock Screen", systemImage: "iphone") }.frame(maxWidth: .infinity, minHeight: 44)
            if !model.presets.isEmpty {
                Text("Your presets").font(HaloTokens.title)
                ForEach(model.presets) { item in
                    HaloCard {
                        VStack(alignment: .leading, spacing: HaloTokens.Space.row) {
                            HStack { Text(item.name).font(.headline); Spacer(); Button { model.removePreset(item.id) } label: { Image(systemName: "trash").frame(width: 44, height: 44) }.accessibilityLabel("Delete preset") }
                            Text("\(ThemeRegistry.theme(item.themeId).name) · \(item.widgetType.title)").font(.caption).foregroundStyle(.secondary)
                            HStack { Button("Load") { preset = item; saved = false }; Spacer(); Button("Make active") { model.activatePreset(item) } }
                        }
                    }
                }
            }
        }.onAppear { if model.presets.isEmpty { preset.themeId = model.theme.id } }
            .onChange(of: preset.widgetType) { _, _ in saved = false }
            .onChange(of: preset.themeId) { _, _ in saved = false }
            .sheet(isPresented: $showCountdown) {
                NavigationStack {
                    Form {
                        TextField("A trip, a birthday, a launch", text: $countdownTitle)
                        DatePicker("Date", selection: $countdownDate, in: Date.now..., displayedComponents: .date)
                        Button("Save countdown") { model.saveCountdown(Countdown(title: countdownTitle, targetDate: countdownDate)); showCountdown = false }.disabled(countdownTitle.isEmpty)
                    }.navigationTitle("Count down to something").toolbar { Button("Close") { showCountdown = false } }
                }
            }
    }
}
struct WidgetGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var message: String?
    @State private var home = false
    private var steps: [String] {
        home ? ["Touch and hold an empty spot on your Home Screen.", "Tap Edit, then Add Widget.", "Search for Halo Day and pick a size.", "Tap Add Widget, then Done."] : ["Touch and hold your Lock Screen, then tap Customize.", "Choose Lock Screen, then tap the widget area under the clock.", "Find Halo Day and tap the widgets you want.", "Tap a widget to choose a preset, then tap Done."]
    }
    var body: some View {
        HaloScreen {
            SectionTitle(title: "Your Halo, on display", subtitle: "You choose the widgets. iOS takes care of the Lock Screen.")
            Picker("Screen", selection: $home) { Text("Lock Screen").tag(false); Text("Home Screen").tag(true) }.pickerStyle(.segmented)
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HaloCard {
                    HStack(alignment: .top, spacing: HaloTokens.Space.card) {
                        Text(index + 1, format: .number).font(HaloTokens.title).foregroundStyle(.tint)
                        Text(LocalizedStringKey(step)).font(.body)
                    }
                }
            }
            Button("I've added it") {
                WidgetCenter.shared.getCurrentConfigurations { result in
                    Task { @MainActor in
                        switch result {
                        case .success(let configurations): message = configurations.isEmpty ? String(localized: "We can't see it yet. Widgets sometimes take a moment. Try again.") : String(localized: "Your Halo is live.")
                        case .failure: message = String(localized: "We can't see it yet. Widgets sometimes take a moment. Try again.")
                        }
                    }
                }
            }.buttonStyle(HaloButtonStyle())
            Button("Copy setup steps") { UIPasteboard.general.string = steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n") }.frame(maxWidth: .infinity, minHeight: 44)
            if let message { Text(message).font(.subheadline).foregroundStyle(.secondary) }
        }.toolbar { Button("Done") { dismiss() } }
    }
}
