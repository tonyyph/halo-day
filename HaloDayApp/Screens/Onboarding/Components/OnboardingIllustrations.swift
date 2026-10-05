import SwiftUI

struct PermissionIllustration: View {
    var calendar: Bool
    private let events = MockData.events()
    @Environment(\.haloReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 16) {
            if calendar {
                HaloCard {
                    VStack(spacing: 0) {
                        ForEach(Array(events.prefix(2).enumerated()), id: \.element.id) { index, event in
                            AgendaRow(event: event)
                                .opacity(appeared ? 1 : 0)
                                .offset(x: appeared || reduceMotion ? 0 : 12)
                                .animation(Motion.resolve(Motion.stagger(index), reduceMotion: reduceMotion), value: appeared)
                        }
                    }
                }
                Label("Your calendar never leaves your iPhone.", systemImage: "lock.fill")
                    .haloFont(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(0..<2, id: \.self) { index in
                    HaloCard {
                        Label(
                            index == 0 ? String(localized: "Design review · in 10 minutes") : String(localized: "A little space to focus"),
                            systemImage: index == 0 ? "calendar.badge.clock" : "timer"
                        )
                        .haloFont(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared || reduceMotion ? 0 : 12)
                    .animation(Motion.resolve(Motion.stagger(index), reduceMotion: reduceMotion), value: appeared)
                }
            }
        }
        .onAppear { appeared = true }
    }
}

struct StarterPresetPicker: View {
    @Binding var selection: WidgetType
    var themeID: String
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.haloReduceMotion) private var reduceMotion
    @Environment(\.haloHapticsEnabled) private var haptics
    @Namespace private var selected
    private let choices: [(WidgetType, String)] = [(.agenda, "Agenda"), (.ritual, "Ritual"), (.month, "Minimal")]

    var body: some View {
        let layout = dynamicType.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(spacing: 8))
        layout {
            ForEach(choices.indices, id: \.self) { index in
                let choice = choices[index]
                Button {
                    withAnimation(Motion.resolve(Motion.snappy, reduceMotion: reduceMotion)) {
                        selection = choice.0
                    }
                } label: {
                    VStack(spacing: 12) {
                        PhonePreview(
                            preset: WidgetPreset(name: choice.1, widgetType: choice.0, themeId: themeID),
                            events: MockData.events(), habits: MockData.habits
                        )
                        .scaleEffect(0.2)
                        .frame(width: 72, height: 90)
                        Text(LocalizedStringKey(choice.1)).haloFont(.subhead)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        if selection == choice.0 {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(palette.accent, lineWidth: 2)
                                .matchedGeometryEffect(id: "starter", in: selected, properties: reduceMotion ? [] : .frame)
                        }
                    }
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(Text(LocalizedStringKey(choice.1)))
                .accessibilityAddTraits(selection == choice.0 ? [.isSelected] : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection) { _, _ in haptics }
    }
}

#Preview("Permissions · Light") {
    DesignPreview { PermissionIllustration(calendar: true) }
}

#Preview("Permissions · Ruby Dark AX3") {
    DesignPreview(themeID: "rubyGlass", scheme: .dark, accessibility: true, reduceMotion: true) {
        PermissionIllustration(calendar: false)
    }
}

#Preview("Starters · Light") {
    @Previewable @State var selection = WidgetType.agenda
    DesignPreview { StarterPresetPicker(selection: $selection, themeID: "pearlHalo") }
}

#Preview("Starters · Gold AX3") {
    @Previewable @State var selection = WidgetType.month
    DesignPreview(themeID: "midnightGold", scheme: .dark, accessibility: true, reduceMotion: true) {
        StarterPresetPicker(selection: $selection, themeID: "midnightGold")
    }
}
