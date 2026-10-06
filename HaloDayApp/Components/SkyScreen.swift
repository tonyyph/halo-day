import SwiftUI

/// The shared v2 backdrop: the current sky behind `content`, with ink, colour scheme and bar styles set from it.
struct SkyScreen<Content: View>: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.haloReferenceDate) private var referenceDate
    private let content: (SkyState, Date) -> Content

    init(@ViewBuilder content: @escaping (SkyState, Date) -> Content) { self.content = content }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = referenceDate ?? context.date
            let sky = SkyEngine.state(sky: model.settings.skyID, at: now, coordinate: model.skyCoordinate)
            ZStack {
                SkyBackground(state: sky)
                content(sky, now)
            }
            .foregroundStyle(sky.inkColor.color)
            .tint(sky.inkColor.color)
            .environment(\.colorScheme, sky.ink == .light ? .dark : .light)
            .toolbarColorScheme(sky.ink == .light ? .dark : .light, for: .navigationBar, .tabBar)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}
