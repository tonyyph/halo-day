import SwiftUI

/// Where a slot sits on the Lock Screen.
struct SlotTarget: Identifiable, Hashable {
    enum Position: Hashable { case inline, slot(Int), add }
    var setupID: UUID
    var position: Position
    var id: String { "\(setupID.uuidString)-\(position)" }
}

extension AccessoryFamily {
    var title: String {
        switch self {
        case .inline: String(localized: "Inline")
        case .circular: String(localized: "Circular")
        case .rectangular: String(localized: "Rectangular")
        }
    }
}

/// A setup drawn as a real Lock Screen: sky wallpaper, the inline line, the clock and the widget row.
struct LockPreview: View {
    var setup: LockSetup
    var data: WidgetData
    var now: Date
    var moment: WallpaperMoment
    var vibrant: Bool
    var coordinate: GeoCoordinate
    var onSlot: (SlotTarget.Position) -> Void

    /// The real Lock Screen this preview is laid out at (6.1" iPhone, points); the whole layout is then scaled to fit,
    /// so text and widgets keep their true proportions instead of being squeezed into a small card.
    static let screen = CGSize(width: 393, height: 852)

    var body: some View {
        let sky = SkyEngine.state(sky: setup.skyID, at: moment.date(on: now, now: now), coordinate: coordinate)
        GeometryReader { proxy in
            let scale = proxy.size.width / Self.screen.width
            ZStack(alignment: .topLeading) {
                WallpaperArt(sky: sky, orbit: setup.wallpaperShowsOrbit ? data.orbit : nil, style: setup.skyID.orbitStyle)
                lockScreen(sky: sky)
                    .frame(width: Self.screen.width, height: Self.screen.height)
                    .scaleEffect(scale, anchor: .topLeading)
                    // scaleEffect doesn't change layout size; pin the layout to the card so it doesn't grow to 393×852.
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(RoundedRectangle(cornerRadius: proxy.size.width * 0.12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: proxy.size.width * 0.12, style: .continuous).strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
        }
        .aspectRatio(Self.screen.width / Self.screen.height, contentMode: .fit)
        .environment(\.colorScheme, sky.ink == .light ? .dark : .light)
    }

    /// Real iOS metrics: the date with the inline widget beside it, the large clock, then the widget row.
    private func lockScreen(sky: SkyState) -> some View {
        VStack(spacing: 10) {
            slotButton(.inline, label: setup.inline.map { "\($0.title), \(AccessoryFamily.inline.title)" } ?? String(localized: "Date")) {
                HStack(spacing: 6) {
                    Text(now, format: .dateTime.weekday(.abbreviated).day())
                    if let inline = setup.inline {
                        AccessoryView(kind: inline, family: .inline, data: data, tint: tint(0, sky))
                    }
                }
                .font(.system(size: 19, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(maxWidth: 330, minHeight: 30)
            }
            Text(now, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                .font(.system(size: 96, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .accessibilityLabel(Text(now, format: .dateTime.hour().minute()))
            HStack(spacing: 10) {
                ForEach(Array(setup.slots.enumerated()), id: \.element.id) { index, slot in
                    slotButton(.slot(index), label: "\(slot.kind.title), \(slot.family.title)") {
                        AccessoryView(kind: slot.kind, family: slot.family, data: data, tint: tint(index + 1, sky))
                            .padding(slot.family == .circular ? 2 : 6)
                            .frame(width: slot.family == .circular ? 72 : 158, height: 72)
                    }
                }
                if setup.remainingUnits > 0 {
                    slotButton(.add, label: String(localized: "Add a widget")) {
                        Image(systemName: "plus").font(.title2).frame(width: 72, height: 72)
                    }
                }
            }
            Spacer()
        }
        .padding(.top, 64)
        .frame(maxWidth: .infinity)
        .foregroundStyle(sky.inkColor.color)
        .dynamicTypeSize(.large)
    }

    /// Vibrant = single ink as iOS draws it; otherwise each slot gets its own colour.
    private func tint(_ index: Int, _ sky: SkyState) -> Color? {
        vibrant ? nil : OrbitPalette.eventColor(Habit.palette[index % Habit.palette.count], sky: sky)
    }

    private func slotButton<Content: View>(_ position: SlotTarget.Position, label: String, @ViewBuilder content: () -> Content) -> some View {
        let id: String = switch position {
        case .inline: "studio-slot-inline"
        case let .slot(index): "studio-slot-\(index)"
        case .add: "studio-slot-add"
        }
        return Button { onSlot(position) } label: {
            content()
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3])).opacity(0.45))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityHint(Text("Choose a widget"))
        .accessibilityIdentifier(id)
    }
}
