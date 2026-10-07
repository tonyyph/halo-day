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

    /// The real Lock Screen this preview is laid out at (6.1-inch iPhone, points).
    static let screen = CGSize(width: 393, height: 852)
    /// The whole device around it: a 14 pt bezel, plus room for the side buttons.
    static let device = CGSize(width: 429, height: 880)
    private static let bezel: CGFloat = 14
    private static let screenRadius: CGFloat = 55

    var body: some View {
        let sky = SkyEngine.state(sky: setup.skyID, at: moment.date(on: now, now: now), coordinate: coordinate)
        GeometryReader { proxy in
            // Laid out at true iPhone points, then scaled as one piece, so text, widgets and hardware keep real proportions.
            phone(sky: sky)
                .frame(width: Self.device.width, height: Self.device.height)
                .scaleEffect(proxy.size.width / Self.device.width, anchor: .topLeading)
                // scaleEffect doesn't change layout size; pin the layout to the available box.
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .aspectRatio(Self.device.width / Self.device.height, contentMode: .fit)
        .environment(\.colorScheme, sky.ink == .light ? .dark : .light)
    }

    /// A titanium iPhone: side buttons, a polished frame, the black bezel, then the Lock Screen with its Dynamic Island.
    private func phone(sky: SkyState) -> some View {
        let outer = Self.screenRadius + Self.bezel
        let body = CGSize(width: Self.screen.width + 2 * Self.bezel, height: Self.screen.height + 2 * Self.bezel)
        return ZStack {
            sideButtons(bodyWidth: body.width)
            RoundedRectangle(cornerRadius: outer, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.78), Color(white: 0.52), Color(white: 0.86), Color(white: 0.44), Color(white: 0.7)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: body.width, height: body.height)
            RoundedRectangle(cornerRadius: outer - 2.5, style: .continuous)
                .fill(Color.black)
                .frame(width: body.width - 5, height: body.height - 5)
            ZStack(alignment: .top) {
                WallpaperArt(sky: sky, orbit: setup.wallpaperShowsOrbit ? data.orbit : nil, style: setup.skyID.orbitStyle)
                lockScreen(sky: sky)
                chrome(sky: sky)
                Capsule().fill(Color.black).frame(width: 126, height: 37).padding(.top, 11)
                    .accessibilityHidden(true)
            }
            .frame(width: Self.screen.width, height: Self.screen.height)
            .clipShape(RoundedRectangle(cornerRadius: Self.screenRadius, style: .continuous))
        }
        .frame(width: Self.device.width, height: Self.device.height)
                .shadow(color: .black.opacity(0.22), radius: 15, x: 12, y: 12)
    }

    /// Action button and volume on the left, the side button on the right.
    private func sideButtons(bodyWidth: CGFloat) -> some View {
        let left = (Self.device.width - bodyWidth) / 2 - 2.5
        let right = Self.device.width - left
        let metal = LinearGradient(colors: [Color(white: 0.5), Color(white: 0.82), Color(white: 0.5)], startPoint: .leading, endPoint: .trailing)
        let buttons: [(x: CGFloat, y: CGFloat, height: CGFloat)] = [(left, 186, 32), (left, 270, 62), (left, 348, 62), (right, 318, 100)]
        return ZStack(alignment: .topLeading) {
            ForEach(buttons.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2).fill(metal)
                    .frame(width: 6, height: buttons[index].height)
                    .position(x: buttons[index].x, y: buttons[index].y)
            }
        }
        .frame(width: Self.device.width, height: Self.device.height, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    /// The Lock Screen's own furniture: status bar, flashlight and camera, home indicator.
    private func chrome(sky: SkyState) -> some View {
        ZStack {
            HStack(spacing: 6) {
                Image(systemName: "cellularbars")
                Image(systemName: "wifi")
                Image(systemName: "battery.75percent").font(.system(size: 20, weight: .regular))
            }
            .font(.system(size: 15, weight: .semibold))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 19)
            .padding(.trailing, 30)
            HStack {
                quickAction("flashlight.off.fill")
                Spacer()
                quickAction("camera.fill")
            }
            .padding(.horizontal, 46)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 50)
            Capsule().frame(width: 134, height: 5)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 8)
        }
        .foregroundStyle(sky.inkColor.color)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func quickAction(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 20, weight: .medium))
            .frame(width: 50, height: 50)
            .background(Circle().fill(Color.black.opacity(0.28)))
            .foregroundStyle(.white)
    }

    /// Real iOS metrics: the date with the inline widget beside it, the large clock, then the widget row.
    private func lockScreen(sky: SkyState) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill").font(.system(size: 17, weight: .semibold)).padding(.bottom, 2)
                .accessibilityHidden(true)
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
            // iOS's widget row: four 72 pt units with 14 pt gaps (a wide widget is two units, 158 pt).
            HStack(spacing: Self.unitGap) {
                ForEach(Array(setup.slots.enumerated()), id: \.element.id) { index, slot in
                    slotButton(.slot(index), label: "\(slot.kind.title), \(slot.family.title)") {
                        AccessoryView(kind: slot.kind, family: slot.family, data: data, tint: tint(index + 1, sky))
                            .padding(slot.family == .circular ? 2 : 6)
                            .frame(width: Self.width(units: slot.family.units), height: Self.unit)
                    }
                }
                if setup.remainingUnits > 0 {
                    slotButton(.add, label: String(localized: "Add a widget")) {
                        // The free space is one target, so the row always spans the width like iOS's edit mode.
                        Image(systemName: "plus").font(.title2).frame(width: Self.width(units: setup.remainingUnits), height: Self.unit)
                    }
                }
            }
            Spacer()
        }
        .padding(.top, 58)
        .frame(maxWidth: .infinity)
        .foregroundStyle(sky.inkColor.color)
        .dynamicTypeSize(.large)
    }

    private static let unit: CGFloat = 72
    private static let unitGap: CGFloat = 14
    private static func width(units: Int) -> CGFloat { CGFloat(units) * unit + CGFloat(max(0, units - 1)) * unitGap }

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
