import SwiftUI

struct FocusIslandPreview: View {
    var session: FocusSession?
    var minutes: Int
    var theme: HaloTheme
    var premium: Bool
    var onUnlock: () -> Void
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion
    @Environment(\.haloReduceTransparency) private var reduceTransparency
    @State private var start = Date.now
    @State private var surface = 0
    @State private var visible = false

    private var attributes: HaloActivityAttributes {
        HaloActivityAttributes(
            title: session?.title ?? String(localized: "Deep work"),
            startDate: session?.startDate ?? start,
            endDate: session?.endDate ?? start.addingTimeInterval(Double(minutes * 60)),
            themeId: theme.id, accentColor: theme.dark.accent
        )
    }

    private var state: HaloActivityAttributes.ContentState {
        .init(endDate: attributes.endDate, pausedRemaining: session?.pausedRemaining)
    }

    var body: some View {
        let accent = PaletteResolver.resolve(theme, scheme: .dark).accent
        let previewTitle = attributes.title
        let previewStart = attributes.startDate
        let previewEnd = state.endDate
        HaloCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("On your Dynamic Island").haloFont(.headline)
                HaloSegmented(options: [(0, "Dynamic Island"), (1, "Lock Screen")], selection: $surface)
                ZStack {
                    Group {
                        if surface == 0 {
                            if visible && !reduceMotion {
                                Color.clear.phaseAnimator(IslandPhase.allCases) { _, phase in
                                    IslandSample(phase: phase, title: previewTitle,
                                                 start: previewStart, end: previewEnd, accent: accent)
                                } animation: { _ in Motion.phase }
                            } else {
                                IslandSample(phase: .compact, title: attributes.title,
                                             start: attributes.startDate, end: state.endDate, accent: accent)
                            }
                        } else {
                            HaloActivityBanner(attributes: attributes, state: state, interactive: false)
                                .background(PaletteResolver.resolve(theme, scheme: .dark).surface,
                                            in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                    }
                    .frame(height: 160)
                    .blur(radius: premium || reduceTransparency ? 0 : 2)
                    .accessibilityHidden(true)

                    if !premium {
                        Button(action: onUnlock) {
                            Label("Unlock Live Activities", systemImage: "sparkle")
                                .haloFont(.subhead)
                                .foregroundStyle(palette.ink)
                                .padding(14)
                                .background {
                                    if reduceTransparency { Capsule().fill(palette.surface) }
                                    else { Capsule().fill(.thinMaterial) }
                                }
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                Text("Live Activities show your timer on the Lock Screen. Dynamic Island appears on supported iPhones.")
                    .haloFont(.footnote)
                    .foregroundStyle(palette.ink2)
            }
        }
        .onAppear { visible = true }
        .onDisappear { visible = false }
    }
}

private enum IslandPhase: CaseIterable {
    case compact, expanded, minimal
    var width: CGFloat { self == .expanded ? 270 : self == .compact ? 210 : 42 }
    var height: CGFloat { self == .expanded ? 128 : 38 }
}

private struct IslandSample: View {
    let phase: IslandPhase
    let title: String
    let start: Date
    let end: Date
    let accent: Color

    nonisolated init(phase: IslandPhase, title: String, start: Date, end: Date, accent: Color) {
        self.phase = phase; self.title = title; self.start = start; self.end = end; self.accent = accent
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "timer").foregroundStyle(accent)
                if phase != .minimal {
                    Text(title).font(.caption).lineLimit(1).foregroundStyle(.white)
                    Spacer(minLength: 0)
                    Text(timerInterval: start...max(start.addingTimeInterval(1), end), countsDown: true)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(accent)
                        .frame(width: 55)
                }
            }
            if phase == .expanded {
                ProgressView(timerInterval: start...max(start.addingTimeInterval(1), end), countsDown: false).tint(accent)
                HStack {
                    Image(systemName: "pause.fill")
                    Spacer()
                    Image(systemName: "stop.fill")
                }
                .font(.caption).foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, phase == .minimal ? 10 : 18)
        .frame(width: phase.width, height: phase.height)
        .background(.black, in: RoundedRectangle(cornerRadius: phase == .expanded ? 26 : 22, style: .continuous))
    }
}

#Preview("Island · Ruby") {
    DesignPreview(themeID: "rubyGlass", scheme: .dark) {
        FocusIslandPreview(minutes: 50, theme: ThemeRegistry.theme("rubyGlass"), premium: true, onUnlock: {})
    }
}

#Preview("Island · Gold Locked AX3") {
    DesignPreview(themeID: "midnightGold", scheme: .dark, accessibility: true, reduceMotion: true) {
        FocusIslandPreview(minutes: 25, theme: ThemeRegistry.theme("midnightGold"), premium: false, onUnlock: {})
    }
}
