import SwiftUI

/// Seven mini-orbits strung along an arc, like beads of light; the selected day is larger and haloed.
struct WeekStrip: View {
    var week: [MiniDay]
    var selected: Date
    var sky: SkyState
    var nowHour: Double?
    var onSelect: (Date) -> Void

    var body: some View {
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
                        }
                        .frame(width: side, height: side)
                    }
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
