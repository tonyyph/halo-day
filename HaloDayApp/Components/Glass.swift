import SwiftUI

/// v2 glass surface: Liquid Glass on iOS 26, material before, a solid sky tint when transparency is reduced.
struct HaloGlass<S: InsettableShape>: ViewModifier {
    var shape: S
    var tint: Color
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(tint, in: shape).overlay(shape.strokeBorder(Color.primary.opacity(0.14), lineWidth: 1))
        } else if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(.ultraThinMaterial, in: shape)
        }
    }
}

extension View {
    func haloGlass<S: InsettableShape>(_ shape: S, tint: Color) -> some View { modifier(HaloGlass(shape: shape, tint: tint)) }
}

struct GlassPillStyle: ButtonStyle {
    var sky: SkyState
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, DS.Space.l)
            .frame(minHeight: 44)
            .haloGlass(Capsule(), tint: sky.mid.color)
            .opacity(isEnabled ? 1 : 0.55)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(DS.Motion.standard, value: configuration.isPressed)
    }
}
