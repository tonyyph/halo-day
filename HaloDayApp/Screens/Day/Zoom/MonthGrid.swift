import SwiftUI

/// The month as rings: thickness is how full a day is, the inner ring closes when every ritual was kept.
struct MonthGrid: View {
    var rows: [[MiniDay?]]
    var month: Date
    var selected: Date
    var sky: SkyState
    var nowHour: Double?
    var onSelect: (Date) -> Void
    var onPage: (Int) -> Void

    var body: some View {
        VStack(spacing: DS.Space.m) {
            HStack {
                Button { onPage(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    .accessibilityLabel(Text("Previous month"))
                    .accessibilityIdentifier("month-previous")
                Spacer()
                Text(month, format: .dateTime.month(.wide).year()).font(DS.Typeface.title(22, relativeTo: .title2))
                Spacer()
                Button { onPage(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                    .accessibilityLabel(Text("Next month"))
                    .accessibilityIdentifier("month-next")
            }
            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol).font(.caption2).opacity(SkyEngine.secondaryOpacity).frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            VStack(spacing: DS.Space.xs) {
                ForEach(rows.indices, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { column in
                            cell(rows[row][column]).frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 30).onEnded { value in
            if abs(value.translation.width) > 60, abs(value.translation.width) > abs(value.translation.height) * 1.5 {
                onPage(value.translation.width < 0 ? 1 : -1)
            }
        })
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("month-grid")
    }

    private var weekdaySymbols: [String] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    @ViewBuilder
    private func cell(_ mini: MiniDay?) -> some View {
        if let mini {
            let isSelected = Calendar.current.isDate(mini.day, inSameDayAs: selected)
            Button { onSelect(mini.day) } label: {
                ZStack {
                    if isSelected {
                        Circle().fill(RadialGradient(colors: [sky.glow.color.opacity(0.6), .clear], center: .center, startRadius: 0, endRadius: 30))
                    }
                    MiniOrbit(mini: mini, sky: sky, nowHour: mini.isToday ? nowHour : nil)
                    Text(mini.day, format: .dateTime.day())
                        .font(.caption.weight(mini.isToday || isSelected ? .bold : .regular))
                }
                .frame(width: 46, height: 46)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(mini.day.formatted(.dateTime.weekday(.wide).day().month(.wide))))
            .accessibilityValue(Text("\(mini.eventCount) events, \(mini.ritualsDone) of \(mini.ritualsTotal) rituals"))
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityIdentifier("month-day-\(mini.key)")
        } else {
            Color.clear.frame(width: 46, height: 46)
        }
    }
}
