import SwiftUI

/// Day · Week · Month — the always-available alternative to pinching.
struct ZoomScaleBar: View {
    var level: ZoomLevel
    var sky: SkyState
    var onChange: (ZoomLevel) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ZoomLevel.allCases) { item in
                Button { onChange(item) } label: {
                    Text(item.title)
                        .font(.footnote.weight(item == level ? .semibold : .regular))
                        .padding(.horizontal, DS.Space.m)
                        .frame(minHeight: 36)
                        .background { if item == level { Capsule().fill(sky.inkColor.color.opacity(0.12)) } }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(item == level ? .isSelected : [])
                .accessibilityIdentifier("zoom-\(item)")
            }
        }
        .padding(4)
        .haloGlass(Capsule(), tint: sky.mid.color)
    }
}
