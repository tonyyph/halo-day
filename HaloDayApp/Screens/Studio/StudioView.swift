import SwiftUI

/// v2 Studio: Lock Screen setups over sky wallpapers, slot editing, wallpapers to Photos and the "Halo today" card.
struct StudioView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.haloScreenshotMode) private var fixture
    @Environment(\.haloToasts) private var toasts
    @State private var selection: UUID?
    @State private var vibrant = true
    @State private var moment: WallpaperMoment = .now
    @State private var editing: SlotTarget?
    @State private var sharing = false
    @State private var saving = false
    @State private var confirmDelete = false
    @State private var photosDenied = false

    var body: some View {
        SkyScreen { sky, now in
            let setups = model.setups
            let current = setups.first { $0.id == selection } ?? setups.first
            let data = widgetData(now: now)
            GeometryReader { screen in
            // Half the screen width (capped on iPad), at true device proportions.
            let phoneWidth = min((screen.size.width - 2 * DS.Space.xl) / 1.5, 280)
            let phoneHeight = phoneWidth * LockPreview.device.height / LockPreview.device.width
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.xl) {
                    header(setups: setups, current: current, sky: sky)
                        .padding(.horizontal, DS.Space.xl)
                    if !setups.isEmpty {
                        TabView(selection: $selection) {
                            ForEach(setups) { setup in
                                LockPreview(setup: setup, data: data, now: now, moment: moment, vibrant: vibrant, coordinate: model.skyCoordinate) {
                                    editing = SlotTarget(setupID: setup.id, position: $0)
                                }
                                .frame(width: phoneWidth, height: phoneHeight)
                                .padding(.vertical, DS.Space.l)
                                .tag(Optional(setup.id))
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: setups.count > 1 ? .always : .never))
                        .frame(height: phoneHeight + 2 * DS.Space.l + (setups.count > 1 ? 28 : 0))
                    }
                    if let current {
                        controls(current, data: data, sky: sky, now: now)
                            .padding(.horizontal, DS.Space.xl)
                    }
                }
                .padding(.vertical, DS.Space.l)
            }
            .scrollIndicators(.hidden)
            }
        }
        .sheet(item: $editing, onDismiss: {
            if model.paywallAfterSheet { model.paywallAfterSheet = false; model.showPaywall = true }
        }) { SlotEditorSheet(target: $0) }
        .alert("Allow Halo Day to add to Photos", isPresented: $photosDenied) {
            Button("Open Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Halo Day only adds the wallpapers you save. It never reads your photos.")
        }
        .sheet(isPresented: $sharing) { ShareCardSheet() }
        .onAppear {
            if model.setups.isEmpty {
                // A lapsed Premium sky must not make the very first setup hit the paywall on every visit.
                let sky = model.purchases.isPremium || !model.settings.skyID.isPremium ? model.settings.skyID : .livingSky
                HaloViewActions.saveSetup(.starter(name: String(localized: "My Halo"), sky: sky), model: model, fixture: fixture)
            }
            if selection == nil { selection = model.activeSetupID ?? model.setups.first?.id }
        }
    }

    private func widgetData(now: Date) -> WidgetData {
        WidgetData(date: now, events: model.events(on: now), habits: model.habits, focus: model.focus,
                   countdown: model.countdowns.first, isSample: model.isSample)
    }

    private func header(setups: [LockSetup], current: LockSetup?, sky: SkyState) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text("Studio").font(DS.Typeface.display(34, relativeTo: .largeTitle)).accessibilityAddTraits(.isHeader)
                if let current, let index = setups.firstIndex(of: current) {
                    Text("\(current.name) · \(index + 1) of \(setups.count)").font(.subheadline).opacity(SkyEngine.secondaryOpacity)
                }
            }
            Spacer()
            Button {
                let setup = LockSetup.starter(name: String(localized: "Halo \(setups.count + 1)"), sky: model.settings.skyID)
                if HaloViewActions.saveSetup(setup, model: model, fixture: fixture) { selection = setup.id }
            } label: { Image(systemName: "plus").frame(width: 44, height: 44) }
            .haloGlass(Circle(), tint: sky.mid.color)
            .accessibilityLabel(Text("New setup"))
            .accessibilityIdentifier("studio-new-setup")
        }
    }

    @ViewBuilder
    private func controls(_ setup: LockSetup, data: WidgetData, sky: SkyState, now: Date) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.l) {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Toggle("As iOS shows it", isOn: $vibrant)
                    .tint(OrbitPalette.ritualColor(sky: sky))
                    .accessibilityIdentifier("studio-vibrant")
                Text("Lock Screen widgets take one colour from your wallpaper. Turn this off to see the design colours.")
                    .font(.footnote).opacity(SkyEngine.secondaryOpacity)
            }
            Text("Sky").font(.headline).accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal) {
                HStack(spacing: DS.Space.s) {
                    ForEach(SkyID.allCases) { id in skyChip(id, setup: setup, sky: sky, now: now) }
                }
            }
            .scrollIndicators(.hidden)
            if setup.skyID.followsSun {
                Text("Moment").font(.headline).accessibilityAddTraits(.isHeader)
                ScrollView(.horizontal) {
                    HStack(spacing: DS.Space.s) {
                        ForEach(WallpaperMoment.allCases) { item in
                            Button { moment = item } label: {
                                Text(item.title).font(.subheadline.weight(moment == item ? .semibold : .regular))
                                    .padding(.horizontal, DS.Space.m).frame(minHeight: 44)
                                    .background { if moment == item { Capsule().fill(sky.inkColor.color.opacity(0.14)) } }
                            }
                            .buttonStyle(.plain)
                            .haloGlass(Capsule(), tint: sky.mid.color)
                            .accessibilityAddTraits(moment == item ? [.isButton, .isSelected] : .isButton)
                            .accessibilityIdentifier("studio-moment-\(item.rawValue)")
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            Toggle("Show Orbit on wallpaper", isOn: Binding(get: { setup.wallpaperShowsOrbit }, set: { value in
                var updated = setup; updated.wallpaperShowsOrbit = value
                HaloViewActions.saveSetup(updated, model: model, fixture: fixture)
            }))
            .tint(OrbitPalette.ritualColor(sky: sky))
            .accessibilityIdentifier("studio-orbit-wallpaper")
            VStack(spacing: DS.Space.m) {
                Button { saveWallpaper(setup, data: data, now: now) } label: {
                    HStack { if saving { ProgressView() }; Label("Save wallpaper", systemImage: "photo.on.rectangle") }.frame(maxWidth: .infinity)
                }
                .buttonStyle(GlassPillStyle(sky: sky))
                .disabled(saving)
                .accessibilityIdentifier("studio-save-wallpaper")
                if !model.purchases.isPremium && !WallpaperMoment.isFree(sky: setup.skyID, moment: moment) {
                    Text("Free wallpapers: Living Sky at dawn and Celestial.").font(.footnote).opacity(SkyEngine.secondaryOpacity)
                }
                Button { sharing = true } label: { Label("Share today", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
                    .buttonStyle(GlassPillStyle(sky: sky))
                    .accessibilityIdentifier("studio-share")
                Button { activate(setup) } label: {
                    Label(model.activeSetupID == setup.id ? "In use on your Lock Screen widgets" : "Use for my widgets",
                          systemImage: model.activeSetupID == setup.id ? "checkmark.circle.fill" : "circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GlassPillStyle(sky: sky))
                .accessibilityIdentifier("studio-activate")
                Button { model.showGuide = true } label: { Label("How to add widgets", systemImage: "questionmark.circle").frame(maxWidth: .infinity) }
                    .buttonStyle(GlassPillStyle(sky: sky))
                    .accessibilityIdentifier("studio-guide")
                if model.setups.count > 1 {
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete setup", systemImage: "trash").frame(maxWidth: .infinity) }
                        .buttonStyle(GlassPillStyle(sky: sky))
                        .accessibilityIdentifier("studio-delete")
                        .confirmationDialog("Delete this setup?", isPresented: $confirmDelete, titleVisibility: .visible) {
                            Button("Delete", role: .destructive) {
                                HaloViewActions.removeSetup(setup, model: model, fixture: fixture)
                                selection = model.setups.first?.id
                            }
                        }
                }
            }
        }
    }

    private func skyChip(_ id: SkyID, setup: LockSetup, sky: SkyState, now: Date) -> some View {
        let state = SkyEngine.state(sky: id, at: moment.date(on: now, now: now), coordinate: model.skyCoordinate)
        let selected = setup.skyID == id
        return Button {
            var updated = setup; updated.skyID = id
            HaloViewActions.saveSetup(updated, model: model, fixture: fixture)
        } label: {
            HStack(spacing: DS.Space.s) {
                Circle()
                    .fill(LinearGradient(colors: [state.top.color, state.bottom.color], startPoint: .top, endPoint: .bottom))
                    .frame(width: 24, height: 24)
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.2), lineWidth: 1))
                Text(id.title).font(.subheadline.weight(selected ? .semibold : .regular))
                if id.isPremium && !model.purchases.isPremium { Image(systemName: "lock.fill").font(.caption2) }
            }
            .padding(.horizontal, DS.Space.m)
            .frame(minHeight: 44)
            .background { if selected { Capsule().fill(sky.inkColor.color.opacity(0.14)) } }
        }
        .buttonStyle(.plain)
        .haloGlass(Capsule(), tint: sky.mid.color)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("studio-sky-\(id.rawValue)")
    }

    private func activate(_ setup: LockSetup) {
        if fixture { model.activeSetupID = setup.id } else { model.activateSetup(setup.id) }
    }

    private func saveWallpaper(_ setup: LockSetup, data: WidgetData, now: Date) {
        guard model.purchases.isPremium || WallpaperMoment.isFree(sky: setup.skyID, moment: moment) else { model.showPaywall = true; return }
        let sky = SkyEngine.state(sky: setup.skyID, at: moment.date(on: now, now: now), coordinate: model.skyCoordinate)
        let art = WallpaperArt(sky: sky, orbit: setup.wallpaperShowsOrbit ? data.orbit : nil, style: setup.skyID.orbitStyle)
        if fixture { _ = ArtRenderer.wallpaper(art); toasts?.show("Wallpaper saved to Photos."); return }
        saving = true
        Task {
            defer { saving = false }
            do {
                try await PhotoSaver.authorize()
                guard let image = ArtRenderer.wallpaper(art) else { return }
                try await PhotoSaver.save(image)
                toasts?.show("Wallpaper saved to Photos.")
            } catch PhotoSaver.Failure.denied {
                photosDenied = true
            } catch {
                model.error = error.localizedDescription
            }
        }
    }
}

/// Preview and share "Halo today"; event names stay hidden unless turned on.
struct ShareCardSheet: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var showTitles = false
    @State private var card: UIImage?

    var body: some View {
        NavigationStack {
            SkyScreen { sky, now in
                let calendar = Calendar.current
                let day = calendar.startOfDay(for: now)
                let events = model.events(on: day)
                let scene = DaySceneBuilder.build(day: day, now: now, events: events, habits: model.habits, focusSessions: model.focusSessions,
                                                  solar: SolarCalculator.day(containing: day, coordinate: model.skyCoordinate, calendar: calendar), calendar: calendar)
                let art = ShareCardArt(scene: scene, sky: sky, style: model.settings.skyID.orbitStyle, showTitles: showTitles, events: events, isSample: model.isSample)
                ScrollView {
                    VStack(spacing: DS.Space.l) {
                        art.frame(width: 270, height: 480)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.glass, style: .continuous))
                            .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
                        Toggle("Show event names", isOn: $showTitles)
                            .tint(OrbitPalette.ritualColor(sky: sky))
                            .accessibilityIdentifier("studio-share-titles")
                        if let image = card {
                            ShareLink(item: Image(uiImage: image), preview: SharePreview(String(localized: "Halo today"), image: Image(uiImage: image))) {
                                Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(GlassPillStyle(sky: sky))
                            .accessibilityIdentifier("studio-share-send")
                        }
                    }
                    .padding(DS.Space.xl)
                }
                // Render the 1080×1920 card only when what it shows changes, not on every minute tick.
                .task(id: showTitles) { card = ArtRenderer.shareCard(art) }
            }
            .navigationTitle("Halo today")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
