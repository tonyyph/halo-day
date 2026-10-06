import SwiftUI

/// Seven mini-orbits strung along an arc, like beads of light; the selected day is larger and haloed.
struct WeekStrip: View {
    var week: [MiniDay]
    var selected: Date
    var sky: SkyState
    var nowHour: Double?
    var onSelect: (Date) -> Void
    var onPage: (Int) -> Void

    var body: some View {
        VStack(spacing: DS.Space.s) {
            HStack {
                Button { onPage(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    .accessibilityLabel(Text("Previous week"))
                    .accessibilityIdentifier("week-previous")
                Spacer()
                if let first = week.first?.day, let last = week.last?.day {
                    Text(first.formatted(.dateTime.day().month(.abbreviated)) + " – " + last.formatted(.dateTime.day().month(.abbreviated)))
                        .font(DS.Typeface.title(18, relativeTo: .headline))
                }
                Spacer()
                Button { onPage(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                    .accessibilityLabel(Text("Next week"))
                    .accessibilityIdentifier("week-next")
            }
            strip
        }
        .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { value in
            if abs(value.translation.width) > 60, abs(value.translation.width) > abs(value.translation.height) * 1.5 {
                onPage(value.translation.width < 0 ? 1 : -1)
            }
        })
    }

    private var strip: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let slot = width / 7
            ForEach(Array(week.enumerated()), id: \.element.id) { index, mini in
                let x = slot * (CGFloat(index) + 0.5)
                let t = (x - width / 2) / (width / 2)
                let isSelected = Calendar.current.isDate(mini.day, inSameDayAs: selected)
                let side = slot * (isSelected ? 1.05 : 0.8)
                Button { onSelect(mini.day) } label: {
                    VStack(spacing: DS.Space.xs) {
                        Text(mini.day, format: .dateTime.weekday(.narrow)).font(.caption2).opacity(SkyEngine.secondaryOpacity)
                        ZStack {
                            if isSelected {
                                Circle().fill(RadialGradient(colors: [sky.glow.color.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: side * 0.7))
                                    .frame(width: side * 1.4, height: side * 1.4)
                            }
                            MiniOrbit(mini: mini, sky: sky, nowHour: mini.isToday ? nowHour : nil)
                            Text(mini.day, format: .dateTime.day())
                                .font(mini.isToday ? .callout.weight(.bold) : .callout)
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        }
                        .frame(width: side, height: side)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .position(x: x, y: proxy.size.height * 0.36 + t * t * proxy.size.height * 0.28)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(label(mini)))
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier("week-day-\(mini.key)")
            }
        }
        .frame(height: 190)
        .animation(DS.Motion.standard, value: selected)
    }

    private func label(_ mini: MiniDay) -> String {
        let day = mini.day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        return String(localized: "\(day), \(mini.eventCount) events, \(mini.ritualsDone) of \(mini.ritualsTotal) rituals")
    }
}
