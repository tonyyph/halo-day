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

    var body: some View {
        let sky = SkyEngine.state(sky: setup.skyID, at: moment.date(on: now, now: now), coordinate: coordinate)
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .top) {
                WallpaperArt(sky: sky, orbit: setup.wallpaperShowsOrbit ? data.orbit : nil, style: setup.skyID.orbitStyle)
                VStack(spacing: width * 0.025) {
                    slotButton(.inline, label: setup.inline.map { "\($0.title), \(AccessoryFamily.inline.title)" } ?? String(localized: "Date")) {
                        Group {
                            if let inline = setup.inline {
                                AccessoryView(kind: inline, family: .inline, data: data, tint: tint(0, sky))
                            } else {
                                Text(now, format: .dateTime.weekday(.wide).day().month(.wide))
                            }
                        }
                        .font(.system(size: width * 0.045, weight: .semibold))
                        .lineLimit(1)
                        .padding(.horizontal, width * 0.03)
                        .frame(height: width * 0.075)
                    }
                    Text(now, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                        .font(.system(size: width * 0.25, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .accessibilityLabel(Text(now, format: .dateTime.hour().minute()))
                    HStack(spacing: width * 0.03) {
                        ForEach(Array(setup.slots.enumerated()), id: \.element.id) { index, slot in
                            slotButton(.slot(index), label: "\(slot.kind.title), \(slot.family.title)") {
                                AccessoryView(kind: slot.kind, family: slot.family, data: data, tint: tint(index + 1, sky))
                                    .padding(slot.family == .circular ? width * 0.01 : width * 0.02)
                                    .frame(width: slot.family == .circular ? width * 0.17 : width * 0.37, height: width * 0.17)
                            }
                        }
                        if setup.remainingUnits > 0 {
                            slotButton(.add, label: String(localized: "Add a widget")) {
                                Image(systemName: "plus").font(.title3).frame(width: width * 0.17, height: width * 0.17)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.top, width * 0.14)
                .foregroundStyle(sky.inkColor.color)
            }
            .clipShape(RoundedRectangle(cornerRadius: width * 0.12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: width * 0.12, style: .continuous).strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
        }
        .aspectRatio(9 / 19.5, contentMode: .fit)
        .environment(\.colorScheme, sky.ink == .light ? .dark : .light)
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
