import SwiftUI

/// Create or edit a ritual: name, when it belongs on the Orbit, its colour and symbol.
struct RitualEditorView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.haloScreenshotMode) private var fixture
    var habit: Habit?
    @State private var title = ""
    @State private var icon = "drop"
    @State private var color = Habit.palette[0]
    @State private var time: TimeOfDay = .morning

    private var limitReached: Bool { habit == nil && !model.purchases.isPremium && model.habits.count >= 3 }
    private var trimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            SkyScreen { sky, _ in
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Space.xl) {
                        HStack(spacing: DS.Space.l) {
                            RitualBead(habit: Habit(title: title, icon: icon, accentColor: color, timeOfDay: time), done: true, size: 64)
                            Text(trimmed.isEmpty ? String(localized: "Your ritual") : trimmed)
                                .font(DS.Typeface.display(28, relativeTo: .title))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        TextField("Ritual name", text: $title)
                            .font(DS.Typeface.title(20))
                            .submitLabel(.done)
                            .padding(DS.Space.m)
                            .haloGlass(RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous), tint: sky.mid.color)
                            .accessibilityIdentifier("ritual-name")
                        section("When") {
                            ViewThatFits {
                                HStack(spacing: DS.Space.s) { timeChips(sky) }
                                VStack(alignment: .leading, spacing: DS.Space.s) { timeChips(sky) }
                            }
                        }
                        section("Color") {
                            HStack(spacing: DS.Space.s) {
                                ForEach(Array(Habit.palette.enumerated()), id: \.offset) { index, hex in
                                    Button { color = hex } label: {
                                        Circle()
                                            .fill((SkyColor(hexString: hex) ?? .white).color)
                                            .frame(width: 34, height: 34)
                                            .overlay(Circle().strokeBorder(sky.inkColor.color, lineWidth: color == hex ? 3 : 0))
                                            .frame(width: 44, height: 44)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(Text("Color \(index + 1)"))
                                    .accessibilityAddTraits(color == hex ? [.isButton, .isSelected] : .isButton)
                                    .accessibilityIdentifier("color-\(index)")
                                }
                            }
                        }
                        section("Symbol") {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Space.s), count: 5), spacing: DS.Space.s) {
                                ForEach(RitualGlyph.all) { glyph in
                                    Button { icon = glyph.symbol } label: {
                                        Image(systemName: glyph.symbol)
                                            .font(.title3)
                                            .frame(maxWidth: .infinity, minHeight: 48)
                                            .background { if icon == glyph.symbol { Circle().fill(sky.inkColor.color.opacity(0.14)) } }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(Text(LocalizedStringKey(glyph.name)))
                                    .accessibilityAddTraits(icon == glyph.symbol ? [.isButton, .isSelected] : .isButton)
                                }
                            }
                        }
                        if limitReached {
                            VStack(alignment: .leading, spacing: DS.Space.s) {
                                Text("Free keeps three rituals. Premium makes room for more.")
                                Button("See Premium") { dismiss(); model.showPaywall = true }
                                    .buttonStyle(GlassPillStyle(sky: sky))
                                    .accessibilityIdentifier("ritual-limit")
                            }
                        }
                    }
                    .padding(DS.Space.xl)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmed.isEmpty || limitReached)
                        .accessibilityIdentifier("ritual-save")
                }
            }
        }
        .onAppear {
            guard let habit else { return }
            title = habit.title; icon = habit.icon; color = habit.accentColor; time = habit.timeOfDay
        }
    }

    private func timeChips(_ sky: SkyState) -> some View {
        ForEach(TimeOfDay.allCases) { item in
            Button { time = item } label: {
                Text(item.title)
                    .font(.subheadline.weight(time == item ? .semibold : .regular))
                    .padding(.horizontal, DS.Space.m)
                    .frame(minHeight: 44)
                    .background { if time == item { Capsule().fill(sky.inkColor.color.opacity(0.14)) } }
            }
            .buttonStyle(.plain)
            .haloGlass(Capsule(), tint: sky.mid.color)
            .accessibilityAddTraits(time == item ? [.isButton, .isSelected] : .isButton)
            .accessibilityIdentifier("time-\(item.rawValue)")
        }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            content()
        }
    }

    /// Applies only the edited fields to the latest stored ritual, so completions recorded meanwhile
    /// (for example by the widget) are kept.
    static func merged(latest: Habit?, original: Habit?, title: String, icon: String, color: String, time: TimeOfDay) -> Habit {
        var value = latest ?? original ?? Habit(title: title, icon: icon, accentColor: color, timeOfDay: time)
        value.title = title
        value.icon = icon
        value.accentColor = color
        value.timeOfDay = time
        return value
    }

    private func save() {
        let latest = habit.flatMap { original in model.habits.first { $0.id == original.id } }
        HaloViewActions.save(Self.merged(latest: latest, original: habit, title: trimmed, icon: icon, color: color, time: time), model: model, fixture: fixture)
        dismiss()
    }
}
