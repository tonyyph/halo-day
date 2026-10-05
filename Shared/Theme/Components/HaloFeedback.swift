import SwiftUI

@MainActor @Observable
final class HaloToastCenter {
    private(set) var message: String?
    private var dismissTask: Task<Void, Never>?

    func show(_ key: String) {
        dismissTask?.cancel()
        message = key
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            message = nil
        }
    }
}

struct HaloToast: View {
    var message: String
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceTransparency) private var reduceTransparency

    var body: some View {
        Label(LocalizedStringKey(message), systemImage: "checkmark.circle.fill")
            .font(HaloFont.subhead)
            .foregroundStyle(palette.ink)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background {
                if reduceTransparency { Capsule().fill(palette.surface) }
                else { Capsule().fill(.thinMaterial) }
            }
            .overlay(Capsule().stroke(palette.glassStroke, lineWidth: 0.5))
            .accessibilityElement(children: .combine)
    }
}

struct ShimmerPlaceholder: View {
    var height: CGFloat = 80
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(palette.surfaceSunken)
            .frame(height: height)
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(colors: [.clear, palette.surface.opacity(0.8), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: proxy.size.width * 0.6)
                            .phaseAnimator([false, true]) { content, phase in
                                content.offset(x: phase ? proxy.size.width : -proxy.size.width)
                            } animation: { _ in Motion.shimmer }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .accessibilityHidden(true)
    }
}

struct DelayedShimmer: View {
    var loading: Bool
    var height: CGFloat = 80
    @State private var visible = false

    var body: some View {
        ShimmerPlaceholder(height: height)
            .opacity(visible && loading ? 1 : 0)
            .task(id: loading) {
                visible = false
                guard loading else { return }
                try? await Task.sleep(for: .milliseconds(150))
                if !Task.isCancelled { visible = true }
            }
    }
}

#Preview("Feedback · Light") {
    DesignPreview {
        VStack(spacing: 20) {
            HaloToast(message: "Preset saved")
            ShimmerPlaceholder()
        }
    }
}

#Preview("Feedback · Gold AX3 Reduced Motion") {
    DesignPreview(themeID: "midnightGold", scheme: .dark, accessibility: true, reduceMotion: true) {
        HaloToast(message: "Welcome to Halo Day Premium.")
    }
}
