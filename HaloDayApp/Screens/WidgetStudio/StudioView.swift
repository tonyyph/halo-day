import SwiftUI
import PhotosUI

struct StudioView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var scheme
    @Environment(\.haloReferenceDate) private var referenceDate
    @Environment(\.haloReduceMotion) private var reduceMotion
    @Environment(\.haloHapticsEnabled) private var haptics
    @Environment(\.haloToasts) private var toasts
    @State private var preset = WidgetPreset(name: String(localized: "My Halo"))
    @State private var wallpaper = StudioWallpaper.light
    @State private var scenario = StudioScenario.live
    @State private var photo: PhotosPickerItem?
    @State private var image: Image?
    @State private var showPhotos = false
    @State private var photoLoading = false
    @State private var selectedSlot = 1
    @State private var selectionPulse = 0
    @State private var appeared = false
    @State private var loaded = false
    @State private var saved = false
    @State private var saving = false
    @State private var deleting: WidgetPreset?
    @State private var showCountdown = false

    var body: some View {
        let date = referenceDate ?? Date.now
        let data = StudioPreviewData(scenario: scenario, date: date, events: model.events(on: date),
                                     habits: model.habits, focus: model.focus,
                                     theme: ThemeRegistry.theme(preset.themeId), sample: model.isSample)
        ZStack {
            ThemeBackground()
            VStack(spacing: 0) {
                HStack {
                    Text("Widget Studio").haloFont(.displayL)
                    Spacer()
                    Image(systemName: "square.on.square.dashed").font(.title2).foregroundStyle(palette.accentInk)
                }
                .padding(.horizontal, 20).padding(.top, 12)

                PhonePreview(
                    preset: preset, events: data.events, habits: data.habits, focus: data.focus,
                    countdown: model.countdowns.first, date: data.date, sample: data.sample,
                    wallpaperScheme: wallpaper.scheme, wallpaper: wallpaper == .photo ? image : nil,
                    selectedSlot: preset.widgetFamily.isAccessory ? selectedSlot : nil,
                    selectionPulse: selectionPulse, onSlotSelect: selectSlot
                )
                .scaleEffect(reduceMotion ? 0.72 : saved ? 0.68 : 0.72)
                .offset(y: saved && !reduceMotion ? 10 : 0)
                .frame(height: 312).frame(maxWidth: .infinity)
                .overlay { DelayedShimmer(loading: photoLoading, height: 300).frame(width: 168).allowsHitTesting(false) }
                .animation(Motion.resolve(Motion.smooth, reduceMotion: reduceMotion), value: saved)
                .haloEntrance(0, appeared: appeared)

                StudioControlTray(preset: $preset, wallpaper: $wallpaper, scenario: $scenario,
                                  saving: saving, saved: saved, date: date, onSave: { Task { await save() } },
                                  onGuide: { model.showGuide = true }, onCountdown: { showCountdown = true },
                                  onLoad: { preset = $0; saved = false }, onDelete: { deleting = $0 })
                .haloEntrance(1, appeared: appeared)
            }
        }
        .onAppear {
            appeared = true
            guard !loaded else { return }
            loaded = true
            preset.themeId = model.theme.id
            wallpaper = scheme == .dark ? .dark : .light
        }
        .onChange(of: preset.widgetType) { _, _ in validateFamily(); saved = false }
        .onChange(of: preset.widgetFamily) { _, new in
            saved = false
            if new == .inline { selectedSlot = 0 }
            else if new == .rectangular { selectedSlot = 1 }
            else if new == .circular && selectedSlot < 2 { selectedSlot = 2 }
        }
        .onChange(of: preset.themeId) { _, _ in saved = false }
        .onChange(of: wallpaper) { _, new in if new == .photo && image == nil { showPhotos = true } }
        .photosPicker(isPresented: $showPhotos, selection: $photo, matching: .images)
        .task(id: photo) {
            guard let photo else { return }
            photoLoading = true
            defer { photoLoading = false }
            if let bytes = try? await photo.loadTransferable(type: Data.self),
               let bitmap = await Task.detached(operation: { StudioBitmap.decode(bytes) }).value {
                image = Image(uiImage: UIImage(cgImage: bitmap.image))
            }
        }
        .confirmationDialog("Delete preset?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), titleVisibility: .visible) {
            Button("Delete preset", role: .destructive) {
                if let deleting { model.removePreset(deleting.id) }
                deleting = nil
            }
        }
        .sensoryFeedback(.warning, trigger: deleting?.id) { _, new in new != nil && haptics }
        .sensoryFeedback(.selection, trigger: selectionPulse) { _, _ in haptics }
        .sheet(isPresented: $showCountdown) { StudioCountdownSheet().haloSheet() }
    }

    private func selectSlot(_ index: Int, _ size: WidgetSize) {
        withAnimation(Motion.resolve(Motion.snappy, reduceMotion: reduceMotion)) {
            if !preset.widgetType.supportedSizes.contains(size) { preset.widgetType = size == .circular ? .month : .agenda }
            preset.widgetFamily = size
            selectedSlot = index
            selectionPulse += 1
        }
    }

    private func validateFamily() {
        guard !preset.widgetType.supportedSizes.contains(preset.widgetFamily) else { return }
        let accessory = preset.widgetFamily.isAccessory
        preset.widgetFamily = preset.widgetType.supportedSizes.first { $0.isAccessory == accessory }
            ?? preset.widgetType.supportedSizes[0]
    }

    private func save() async {
        guard !saving else { return }
        saving = true
        await Task.yield()
        if model.presets.contains(where: { $0.id == preset.id }) { preset.id = UUID() }
        preset.updatedAt = .now
        var success = false
        withAnimation(Motion.resolve(Motion.smooth, reduceMotion: reduceMotion)) { success = model.savePreset(preset) }
        saving = false
        guard success else { return }
        saved = true
        preset.id = UUID()
        toasts?.show("Preset saved")
        try? await Task.sleep(for: .seconds(1.5))
        saved = false
    }
}

#Preview("Studio · Pearl") {
    StudioView().environment(HaloModel()).haloTheme(ThemeRegistry.theme("pearlHalo"))
}

#Preview("Studio · Gold AX3 Reduced Motion") {
    StudioView().environment(HaloModel()).haloTheme(ThemeRegistry.theme("midnightGold"))
        .environment(\.dynamicTypeSize, .accessibility3)
        .environment(\.haloReduceMotionOverride, true)
}
