import SwiftUI

@MainActor @Observable
final class HaloNavigationState {
    var eventSource = "event"
    var focusSource = "focus-session"
}

private struct NamespaceKey: EnvironmentKey { static let defaultValue: Namespace.ID? = nil }
private struct NavigationStateKey: EnvironmentKey { static let defaultValue: HaloNavigationState? = nil }

extension EnvironmentValues {
    var haloNamespace: Namespace.ID? {
        get { self[NamespaceKey.self] }
        set { self[NamespaceKey.self] = newValue }
    }

    var haloNavigation: HaloNavigationState? {
        get { self[NavigationStateKey.self] }
        set { self[NavigationStateKey.self] = newValue }
    }
}

private struct ZoomSource: ViewModifier {
    let id: String
    @Environment(\.haloNamespace) private var namespace
    @Environment(\.haloReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if let namespace, !reduceMotion {
            content.matchedTransitionSource(id: id, in: namespace)
        } else { content }
    }
}

private struct ZoomDestination: ViewModifier {
    let id: String
    @Environment(\.haloNamespace) private var namespace
    @Environment(\.haloReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if let namespace, !reduceMotion {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else { content.navigationTransition(.automatic) }
    }
}

private struct TabMotion: ViewModifier {
    var selected: Bool
    @Environment(\.haloReduceMotion) private var reduceMotion
    @State private var visible = true

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 8)
            .onChange(of: selected) { _, value in
                guard value else { return }
                visible = false
                Task { @MainActor in
                    await Task.yield()
                    withAnimation(Motion.resolve(Motion.smooth, reduceMotion: reduceMotion)) {
                        visible = true
                    }
                }
            }
    }
}

private struct HaloSheet: ViewModifier {
    var detents: Set<PresentationDetent>
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .haloToastHost()
            .presentationDetents(detents)
            .presentationCornerRadius(32)
            .presentationBackground(reduceTransparency ? AnyShapeStyle(palette.bg) : AnyShapeStyle(.thinMaterial))
    }
}

extension View {
    func haloZoomSource(_ id: String) -> some View { modifier(ZoomSource(id: id)) }
    func haloZoomDestination(_ id: String) -> some View { modifier(ZoomDestination(id: id)) }
    func haloTabMotion(selected: Bool) -> some View { modifier(TabMotion(selected: selected)) }
    func haloSheet(_ detents: Set<PresentationDetent> = [.medium, .large]) -> some View {
        modifier(HaloSheet(detents: detents))
    }
}
