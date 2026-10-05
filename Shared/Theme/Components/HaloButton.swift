import SwiftUI

enum HaloButtonKind { case primary, secondary, glass, text }

struct HaloActionStyle: ButtonStyle {
    var kind: HaloButtonKind = .primary
    var loading = false
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion
    @Environment(\.haloReduceTransparency) private var reduceTransparency
    @Environment(\.haloHapticsEnabled) private var haptics
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .haloFont(.headline)
            .foregroundStyle(kind == .primary ? palette.accentOn : kind == .text ? palette.accentInk : palette.ink)
            .frame(maxWidth: kind == .text ? nil : .infinity)
            .frame(minHeight: kind == .text ? 44 : 56)
            .padding(.horizontal, kind == .text ? 8 : 20)
            .background {
                switch kind {
                case .primary: Capsule().fill(palette.accent)
                case .secondary: Capsule().fill(palette.surface)
                case .glass:
                    if reduceTransparency { Capsule().fill(palette.surface) }
                    else if #available(iOS 26.0, *) {
                        Capsule().fill(.clear).glassEffect(.regular, in: Capsule())
                    } else { Capsule().fill(.ultraThinMaterial) }
                case .text: Color.clear
                }
            }
            .overlay {
                if kind == .primary {
                    Capsule().stroke(.white.opacity(0.2), lineWidth: 1).padding(1)
                } else if kind != .text {
                    Capsule().stroke(palette.hairline, lineWidth: 0.5)
                }
            }
            .shadow(color: palette.accent.opacity(configuration.isPressed && kind == .primary ? 0.25 : 0), radius: 20)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.02 : 0)
            .opacity(enabled || loading ? 1 : 0.38)
            .animation(Motion.resolve(Motion.snappy, reduceMotion: reduceMotion), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in
                pressed && haptics && enabled
            }
    }
}

struct HaloButton: View {
    var title: String
    var kind: HaloButtonKind = .primary
    var isLoading = false
    var isSuccess = false
    var emitSuccessFeedback = true
    var action: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion
    @Environment(\.haloHapticsEnabled) private var haptics
    @State private var showSuccess = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(LocalizedStringKey(title))
                    .opacity(isLoading || showSuccess ? 0 : 1)
                ProgressView()
                    .tint(kind == .primary ? palette.accentOn : palette.ink)
                    .opacity(isLoading ? 1 : 0)
                Image(systemName: "checkmark")
                    .contentTransition(.symbolEffect(.replace))
                    .opacity(showSuccess ? 1 : 0)
            }
            .animation(Motion.resolve(Motion.snappy, reduceMotion: reduceMotion), value: isLoading)
            .animation(Motion.resolve(Motion.snappy, reduceMotion: reduceMotion), value: showSuccess)
        }
        .buttonStyle(HaloActionStyle(kind: kind, loading: isLoading))
        .disabled(isLoading)
        .accessibilityLabel(Text(LocalizedStringKey(title)))
        .sensoryFeedback(.success, trigger: isSuccess) { _, success in success && haptics && emitSuccessFeedback }
        .task(id: isSuccess) {
            guard isSuccess else { showSuccess = false; return }
            showSuccess = true
            try? await Task.sleep(for: .seconds(1.5))
            if !Task.isCancelled { showSuccess = false }
        }
    }
}

#Preview("Buttons · Light") {
    DesignPreview {
        VStack(spacing: 16) {
            HaloButton(title: "Save preset") { }
            HaloButton(title: "Continue", kind: .secondary) { }
            HaloButton(title: "Continue", kind: .glass, isLoading: true) { }
            HaloButton(title: "Restore purchases", kind: .text) { }
        }
    }
}

#Preview("Buttons · Midnight AX3") {
    DesignPreview(themeID: "midnightGold", scheme: .dark, accessibility: true, reduceMotion: true) {
        HaloButton(title: "Save preset", isSuccess: true) { }
    }
}
