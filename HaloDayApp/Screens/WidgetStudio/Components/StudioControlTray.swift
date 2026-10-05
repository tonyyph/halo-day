import SwiftUI

struct StudioControlTray: View {
    @Binding var preset: WidgetPreset
    @Binding var wallpaper: StudioWallpaper
    @Binding var scenario: StudioScenario
    var saving: Bool
    var saved: Bool
    var date: Date
    var onSave: () -> Void
    var onGuide: () -> Void
    var onCountdown: () -> Void
    var onLoad: (WidgetPreset) -> Void
    var onDelete: (WidgetPreset) -> Void
    @Environment(HaloModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceTransparency) private var reduceTransparency

    private var isHome: Binding<Bool> {
        Binding(get: { !preset.widgetFamily.isAccessory }, set: { home in
            let families = preset.widgetType.supportedSizes.filter { $0.isAccessory != home }
            if let first = families.first { preset.widgetFamily = first }
            else { preset.widgetType = .agenda; preset.widgetFamily = home ? .small : .rectangular }
        })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(preset.widgetFamily.isAccessory
                     ? String(localized: "Lock Screen colors follow your wallpaper. This preview shows the layout.")
                     : String(localized: "Home Screen widgets show your theme in full color."))
                    .haloFont(.footnote).foregroundStyle(palette.ink2)
                TextField("Preset name", text: $preset.name).haloFont(.displayS).textFieldStyle(.plain)
                    .submitLabel(.done).accessibilityLabel("Preset name")

                HaloSegmented(options: [(false, "Lock Screen"), (true, "Home Screen")], selection: isHome)
                selector("Widget size") {
                    ChipGroup(options: preset.widgetType.supportedSizes.filter { $0.isAccessory == preset.widgetFamily.isAccessory }
                        .map { ($0, $0.rawValue.capitalized) }, selection: $preset.widgetFamily)
                }
                selector("Widget type") {
                    ChipGroup(options: WidgetType.allCases.map { ($0, $0.title) }, selection: $preset.widgetType)
                }
                selector("Wallpaper") {
                    ChipGroup(options: StudioWallpaper.allCases.map { ($0, $0.rawValue) }, selection: $wallpaper)
                }
                selector("Preview data") {
                    ChipGroup(options: StudioScenario.allCases.map { ($0, $0.rawValue) }, selection: $scenario)
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Theme").captionUpper().foregroundStyle(palette.ink2)
                        Spacer()
                        NavigationLink("Explore all themes") { ThemesView() }.haloFont(.footnote).frame(minHeight: 44)
                    }
                    ThemeOrbPicker(selection: $preset.themeId)
                }
                if preset.widgetType == .countdown { Button("Add countdown", action: onCountdown).frame(minHeight: 44) }
                HaloButton(title: "Save preset", isLoading: saving, isSuccess: saved, action: onSave)
                    .disabled(preset.name.trimmingCharacters(in: .whitespaces).isEmpty)
                HaloButton(title: "How to add to Lock Screen", kind: .text, action: onGuide)
                if !model.presets.isEmpty {
                    StudioPresetCarousel(presets: model.presets, events: model.events(on: date), habits: model.habits, date: date,
                                         onLoad: onLoad, onActivate: { model.activatePreset($0) }, onDelete: onDelete)
                }
            }
            .frame(maxWidth: 600, alignment: .leading).padding(20).frame(maxWidth: .infinity)
        }
        .background {
            let shape = UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous)
            if reduceTransparency { shape.fill(palette.surface) }
            else if #available(iOS 26.0, *) { shape.fill(.clear).glassEffect(.regular, in: shape) }
            else { shape.fill(.ultraThinMaterial).overlay(shape.stroke(palette.glassStroke, lineWidth: 0.5)) }
        }
    }

    private func selector<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey(title)).captionUpper().foregroundStyle(palette.ink2)
            content()
        }
    }
}

struct StudioCountdownSheet: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var date = Date.now.addingTimeInterval(86400 * 14)

    var body: some View {
        NavigationStack {
            Form {
                TextField("A trip, a birthday, a launch", text: $title)
                DatePicker("Date", selection: $date, in: Date.now..., displayedComponents: .date)
                Button("Save countdown") {
                    model.saveCountdown(Countdown(title: title, targetDate: date))
                    dismiss()
                }.disabled(title.isEmpty)
            }
            .navigationTitle("Count down to something")
            .toolbar { Button("Close") { dismiss() } }
        }
    }
}
