import SwiftUI

struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.02 : 0)
            .animation(Motion.resolve(Motion.snappy, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

struct HaloChip: View {
    var title: String
    var selected: Bool
    var action: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.haloHapticsEnabled) private var haptics

    var body: some View {
        Button(action: action) {
            Text(LocalizedStringKey(title))
                .font(HaloFont.subhead)
                .foregroundStyle(selected ? palette.accentOn : palette.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(selected ? palette.accent : palette.surfaceSunken, in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .sensoryFeedback(.selection, trigger: selected) { _, _ in haptics }
    }
}

struct ChipGroup<Value: Hashable>: View {
    var options: [(value: Value, title: String)]
    @Binding var selection: Value

    @Environment(\.palette) private var palette
    @Environment(\.haloHapticsEnabled) private var haptics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var indicator

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(options.indices, id: \.self) { index in
                    let option = options[index]
                    Button {
                        withAnimation(Motion.resolve(Motion.snappy, reduceMotion: reduceMotion)) {
                            selection = option.value
                        }
                    } label: {
                        Text(LocalizedStringKey(option.title))
                            .font(HaloFont.subhead)
                            .foregroundStyle(selection == option.value ? palette.accentOn : palette.ink)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background {
                                if selection == option.value {
                                    Capsule()
                                        .fill(palette.accent)
                                        .matchedGeometryEffect(id: "selected", in: indicator)
                                } else {
                                    Capsule().fill(palette.surfaceSunken)
                                }
                            }
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(selection == option.value ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .sensoryFeedback(.selection, trigger: selection) { _, _ in haptics }
    }
}

struct HaloSegmented<Value: Hashable>: View {
    var options: [(value: Value, title: String)]
    @Binding var selection: Value

    @Environment(\.palette) private var palette
    @Environment(\.haloHapticsEnabled) private var haptics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var thumb

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                Button {
                    withAnimation(Motion.resolve(Motion.snappy, reduceMotion: reduceMotion)) {
                        selection = option.value
                    }
                } label: {
                    Text(LocalizedStringKey(option.title))
                        .font(HaloFont.subhead)
                        .foregroundStyle(selection == option.value ? palette.ink : palette.ink2)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background {
                            if selection == option.value {
                                Capsule()
                                    .fill(palette.surface)
                                    .matchedGeometryEffect(id: "thumb", in: thumb)
                                    .shadow(color: palette.shadowTint.opacity(0.1), radius: 4, y: 2)
                            }
                        }
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(selection == option.value ? [.isSelected] : [])
            }
        }
        .padding(3)
        .background(palette.surfaceSunken, in: Capsule())
        .sensoryFeedback(.selection, trigger: selection) { _, _ in haptics }
        .accessibilityRepresentation {
            Picker("View", selection: $selection) {
                ForEach(options.indices, id: \.self) { index in
                    Text(LocalizedStringKey(options[index].title))
                        .tag(options[index].value)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

#Preview("Segments · Ruby Dark") {
    @Previewable @State var selection = 0
    HaloSegmented(options: [(0, "Day"), (1, "Week"), (2, "Month")], selection: $selection)
        .padding()
        .environment(\.palette, PaletteResolver.resolve(ThemeRegistry.theme("rubyGlass"), scheme: .dark))
        .preferredColorScheme(.dark)
}
