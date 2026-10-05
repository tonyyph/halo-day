import SwiftUI

struct HaloPagerIndicator: View {
    var total: Int
    var selection: Int
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion
    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { index in
                ZStack {
                    Circle().fill(palette.ink3.opacity(0.4)).frame(width: 6, height: 6)
                    if index == selection {
                        Capsule()
                            .fill(palette.ink)
                            .frame(width: 18, height: 6)
                            .matchedGeometryEffect(id: "page", in: indicator, properties: reduceMotion ? [] : .frame)
                    }
                }
                .frame(width: 18, height: 6)
            }
        }
        .animation(Motion.resolve(Motion.snappy, reduceMotion: reduceMotion), value: selection)
        .accessibilityHidden(true)
    }
}

#Preview("Pager · Light") {
    DesignPreview { HaloPagerIndicator(total: 6, selection: 2) }
}

#Preview("Pager · Midnight AX3 Reduced Motion") {
    DesignPreview(themeID: "midnightGold", scheme: .dark, accessibility: true, reduceMotion: true) {
        HaloPagerIndicator(total: 6, selection: 5)
    }
}
