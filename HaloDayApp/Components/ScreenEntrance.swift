import SwiftUI

private struct ScreenEntrance: ViewModifier {
    var index: Int
    var appeared: Bool
    @Environment(\.haloReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 12)
            .animation(Motion.resolve(Motion.stagger(index), reduceMotion: reduceMotion), value: appeared)
    }
}

extension View {
    func haloEntrance(_ index: Int, appeared: Bool) -> some View {
        modifier(ScreenEntrance(index: index, appeared: appeared))
    }
}
