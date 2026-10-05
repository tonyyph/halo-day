import SwiftUI

struct StudioView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion
    @Environment(\.haloHapticsEnabled) private var haptics

    @State private var preset = WidgetPreset(name: "My Halo")
    @State private var saved = false
    @State private var saving = false
    @State private var deletingPreset: WidgetPreset?
    @State private var showCountdown = false
    @State private var countdownTitle = ""
    @State private var countdownDate = Date.now.addingTimeInterval(86400 * 14)

    private var isHome: Binding<Bool> {
        Binding(
            get: { !preset.widgetFamily.isAccessory },
            set: { home in
                withAnimation(Motion.resolve(Motion.smooth, reduceMotion: reduceMotion)) {
                    preset.widgetFamily = home ? .medium : .rectangular
                }
            }
        )
    }

    private var sizes: [WidgetSize] {
        WidgetSize.allCases.filter { $0.isAccessory != isHome.wrappedValue }
    }

    var body: some View {
        ZStack {
            ThemeBackground()

            VStack(spacing: 0) {
                HStack {
                    Text("Widget Studio")
                        .haloFont(.displayL)
                    Spacer()
                    Image(systemName: "square.on.square.dashed")
                        .font(.title2)
                        .foregroundStyle(palette.accentInk)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                PhonePreview(
                    preset: preset,
                    events: model.todayEvents,
                    habits: model.habits,
                    focus: model.focus,
                    countdown: model.countdowns.first,
                    sample: model.isSample
                )
                .scaleEffect(reduceMotion ? 0.7 : 0.72)
                .frame(height: 312)
                .frame(maxWidth: .infinity)
                .animation(Motion.resolve(Motion.gentle, reduceMotion: reduceMotion), value: preset.themeId)
                .accessibilityLabel("Widget preview")

                controls
            }
        }
        .overlay(alignment: .top) {
            if saved {
                Label("Preset saved", systemImage: "checkmark.circle.fill")
                    .haloFont(.subhead)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .onAppear { if model.presets.isEmpty { preset.themeId = model.theme.id } }
        .onChange(of: preset.widgetType) { _, _ in saved = false }
        .onChange(of: preset.themeId) { _, _ in saved = false }
        .onChange(of: preset.widgetFamily) { _, _ in saved = false }
        .sensoryFeedback(.success, trigger: saved) { _, new in haptics && new }
        .confirmationDialog(
            "Delete preset?",
            isPresented: Binding(get: { deletingPreset != nil }, set: { if !$0 { deletingPreset = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete preset", role: .destructive) {
                if let deletingPreset { model.removePreset(deletingPreset.id) }
                deletingPreset = nil
            }
        }
        .sheet(isPresented: $showCountdown) { countdownSheet }
    }

    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(preset.widgetFamily.isAccessory
                     ? "Lock Screen colors follow your wallpaper. This preview shows the layout."
                     : "Home Screen widgets show your theme in full color.")
                    .haloFont(.footnote)
                    .foregroundStyle(palette.ink2)

                TextField("Preset name", text: $preset.name)
                    .haloFont(.displayS)
                    .textFieldStyle(.plain)
                    .submitLabel(.done)
                    .accessibilityLabel("Preset name")

                VStack(alignment: .leading, spacing: 12) {
                    Text("Surface").captionUpper().foregroundStyle(palette.ink2)
                    HaloSegmented(
                        options: [(false, "Lock Screen"), (true, "Home Screen")],
                        selection: isHome
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Widget size").captionUpper().foregroundStyle(palette.ink2)
                    ChipGroup(
                        options: sizes.map { ($0, $0.rawValue.capitalized) },
                        selection: $preset.widgetFamily
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Widget type").captionUpper().foregroundStyle(palette.ink2)
                    ChipGroup(
                        options: WidgetType.allCases.map { ($0, $0.title) },
                        selection: $preset.widgetType
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Theme").captionUpper().foregroundStyle(palette.ink2)
                        Spacer()
                        NavigationLink("Explore all themes") { ThemesView() }
                            .haloFont(.footnote)
                    }
                    ThemeOrbPicker(selection: $preset.themeId)
                }

                if preset.widgetType == .countdown {
                    Button("Add countdown") { showCountdown = true }
                        .frame(minHeight: 44)
                }

                Button {
                    Task { await save() }
                } label: {
                    Group {
                        if saving { ProgressView().tint(palette.accentOn) }
                        else if saved { Label("Saved beautifully", systemImage: "checkmark") }
                        else { Text("Save preset") }
                    }
                    .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(HaloButtonStyle())
                .disabled(saving || preset.name.trimmingCharacters(in: .whitespaces).isEmpty)

                Button { model.showGuide = true } label: {
                    Label("How to add to Lock Screen", systemImage: "iphone")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PressableStyle())

                if !model.presets.isEmpty { presetCarousel }
            }
            .frame(maxWidth: 600, alignment: .leading)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 32,
                topTrailingRadius: 32,
                style: .continuous
            )
            .fill(palette.surface.opacity(0.94))
            .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(palette.hairline)
                .frame(width: 36, height: 4)
                .padding(.top, 8)
        }
    }

    private var presetCarousel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your presets").haloFont(.displayM)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(model.presets) { item in
                        Button { preset = item; saved = false } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: "iphone.gen3")
                                    .font(.largeTitle)
                                    .foregroundStyle(PaletteResolver.resolve(
                                        ThemeRegistry.theme(item.themeId), scheme: .light
                                    ).accent)
                                    .frame(maxWidth: .infinity, minHeight: 80)
                                Text(item.name)
                                    .haloFont(.subhead)
                                    .lineLimit(1)
                            }
                            .padding(12)
                            .frame(width: 130)
                            .background(palette.surfaceSunken, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(PressableStyle())
                        .contextMenu {
                            Button("Load") { preset = item; saved = false }
                            Button("Make active") { model.activatePreset(item) }
                            Button("Delete preset", role: .destructive) { deletingPreset = item }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var countdownSheet: some View {
        NavigationStack {
            Form {
                TextField("A trip, a birthday, a launch", text: $countdownTitle)
                DatePicker("Date", selection: $countdownDate, in: Date.now..., displayedComponents: .date)
                Button("Save countdown") {
                    model.saveCountdown(Countdown(title: countdownTitle, targetDate: countdownDate))
                    showCountdown = false
                }
                .disabled(countdownTitle.isEmpty)
            }
            .navigationTitle("Count down to something")
            .toolbar { Button("Close") { showCountdown = false } }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(32)
    }

    private func save() async {
        saving = true
        preset.updatedAt = .now
        if model.savePreset(preset) {
            saving = false
            withAnimation(Motion.resolve(Motion.snappy, reduceMotion: reduceMotion)) { saved = true }
            preset.id = UUID()
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(Motion.resolve(Motion.snappy, reduceMotion: reduceMotion)) { saved = false }
        } else {
            saving = false
        }
    }
}

#Preview { StudioView().environment(HaloModel()) }
