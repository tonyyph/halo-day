import SwiftUI

struct HabitEditorView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion
    @Environment(\.haloHapticsEnabled) private var haptics
    @Namespace private var glyphSelection

    var habit: Habit?
    @State private var title = ""
    @State private var icon = "drop"

    var body: some View {
        NavigationStack {
            HaloScreen {
                SectionTitle(title: habit == nil ? "A small beginning" : "Your ritual")

                HaloCard(hero: true) {
                    HStack(spacing: 16) {
                        Image(systemName: icon)
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(palette.accentInk)
                            .frame(width: 64, height: 64)
                            .background(palette.accentSoft, in: Circle())
                        Text(title.isEmpty ? String(localized: "Your ritual") : title)
                            .haloFont(.displayM)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Ritual name").captionUpper().foregroundStyle(palette.ink2)
                    TextField("Ritual name", text: $title)
                        .haloFont(.displayM)
                        .textFieldStyle(.plain)
                        .frame(minHeight: 44)
                        .submitLabel(.done)
                }

                Text("Symbol").captionUpper().foregroundStyle(palette.ink2)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 12) {
                    ForEach(RitualGlyph.all) { glyph in
                        Button {
                            withAnimation(Motion.resolve(Motion.snappy, reduceMotion: reduceMotion)) {
                                icon = glyph.symbol
                            }
                        } label: {
                            Image(systemName: glyph.symbol)
                                .font(.system(size: 22, weight: .regular))
                                .foregroundStyle(icon == glyph.symbol ? palette.accentInk : palette.ink2)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(palette.surfaceSunken, in: Circle())
                                .overlay {
                                    if icon == glyph.symbol {
                                        Circle()
                                            .stroke(palette.accent, lineWidth: 2)
                                            .matchedGeometryEffect(
                                                id: "glyph", in: glyphSelection,
                                                properties: reduceMotion ? [] : .frame
                                            )
                                    }
                                }
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel(Text(LocalizedStringKey(glyph.name)))
                        .accessibilityAddTraits(icon == glyph.symbol ? [.isSelected] : [])
                    }
                }

                HaloButton(title: "Save ritual") { save() }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .toolbar { Button("Close") { dismiss() } }
        }
        .onAppear {
            title = habit?.title ?? ""
            icon = habit?.icon ?? "drop"
        }
        .sensoryFeedback(.selection, trigger: icon) { _, _ in haptics }
    }

    private func save() {
        var value = habit ?? Habit(title: title, icon: icon, accentColor: model.theme.accentColor)
        value.title = title.trimmingCharacters(in: .whitespaces)
        value.icon = icon
        model.saveHabit(value)
        dismiss()
    }
}

private struct RitualGlyph: Identifiable {
    let symbol: String
    let name: String
    var id: String { symbol }

    static let all: [RitualGlyph] = [
        ("drop", "Water"), ("book.closed", "Reading"), ("figure.walk", "Walk"),
        ("leaf", "Plants"), ("sun.max", "Sunshine"), ("moon.stars", "Rest"),
        ("pencil", "Writing"), ("heart", "Wellbeing"), ("cup.and.saucer", "Tea"),
        ("dumbbell", "Exercise"), ("bed.double", "Sleep"), ("face.smiling", "Smile"),
        ("pills", "Medication"), ("bag", "Shopping"), ("music.note", "Music"),
        ("camera", "Photography"), ("paintbrush", "Painting"), ("brain.head.profile", "Learning"),
        ("wind", "Breathe"), ("fork.knife", "Food"), ("figure.run", "Running"),
        ("figure.outdoor.cycle", "Cycling"), ("figure.pool.swim", "Swimming"),
        ("figure.yoga", "Yoga"), ("figure.flexibility", "Stretching"),
        ("briefcase", "Work"), ("calendar", "Calendar"), ("pencil.line", "Journal"),
        ("house", "Home"), ("airplane", "Travel"), ("globe", "Language"),
        ("lightbulb", "Creativity"), ("sparkles", "Gratitude"),
        ("waterbottle", "Hydration"), ("flame", "Cooking"), ("timer", "Quiet time"),
        ("lungs", "Fresh air"), ("eyes", "Screen break"), ("person.2", "Family"),
        ("hands.sparkles", "Self care")
    ].map { RitualGlyph(symbol: $0.0, name: $0.1) }
}

#Preview("Ritual editor · Ruby Dark") {
    HabitEditorView().environment(HaloModel())
        .haloTheme(ThemeRegistry.theme("rubyGlass"))
        .preferredColorScheme(.dark)
}

#Preview("Ritual editor · Pearl AX3") {
    HabitEditorView().environment(HaloModel())
        .haloTheme(ThemeRegistry.theme("pearlHalo"))
        .environment(\.dynamicTypeSize, .accessibility3)
        .environment(\.haloReduceMotionOverride, true)
}
