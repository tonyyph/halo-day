import SwiftUI

/// A ritual's bead: filled and glowing when kept today, an outline when not.
struct RitualBead: View {
    var habit: Habit
    var done: Bool
    var size: CGFloat

    var body: some View {
        let color = (SkyColor(hexString: habit.accentColor) ?? .white).color
        ZStack {
            Circle().fill(done ? color : .clear)
            Circle().strokeBorder(color, lineWidth: max(2, size * 0.04))
            Image(systemName: habit.icon)
                .font(.system(size: size * 0.42, weight: .regular))
                .foregroundStyle(done ? Color.white : color)
        }
        .frame(width: size, height: size)
        .shadow(color: done ? color.opacity(0.6) : .clear, radius: size * 0.18)
        .accessibilityHidden(true)
    }
}

/// One ritual in the You list.
struct RitualLine: View {
    var habit: Habit
    var sky: SkyState
    var now: Date

    var body: some View {
        HStack(spacing: DS.Space.l) {
            RitualBead(habit: habit, done: habit.isCompleted(on: now), size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.title).font(.body.weight(.medium)).multilineTextAlignment(.leading)
                Text("\(habit.timeOfDay.title) · \(habit.streak(asOf: now)) day streak")
                    .font(.footnote)
                    .opacity(SkyEngine.secondaryOpacity)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote).opacity(SkyEngine.secondaryOpacity).accessibilityHidden(true)
        }
        .padding(DS.Space.m)
        .haloGlass(RoundedRectangle(cornerRadius: DS.Radius.glass, style: .continuous), tint: sky.mid.color)
        .accessibilityElement(children: .combine)
    }
}

/// Twelve weeks of a ritual as dots: filled = kept, faint ring = missed, empty = still to come.
struct RitualHistoryDots: View {
    var grid: [[Bool?]]
    var color: Color
    var sky: SkyState

    var body: some View {
        let kept = grid.flatMap { $0 }.filter { $0 == true }.count
        HStack(spacing: 5) {
            ForEach(grid.indices, id: \.self) { week in
                VStack(spacing: 5) {
                    ForEach(0..<7, id: \.self) { day in dot(grid[week][day]) }
                }
            }
        }
        .padding(DS.Space.l)
        .frame(maxWidth: .infinity)
        .haloGlass(RoundedRectangle(cornerRadius: DS.Radius.glass, style: .continuous), tint: sky.mid.color)
        .accessibilityElement()
        .accessibilityLabel(Text("Last 12 weeks"))
        .accessibilityValue(Text("\(kept) days kept"))
    }

    @ViewBuilder
    private func dot(_ value: Bool?) -> some View {
        switch value {
        case .some(true): Circle().fill(color).frame(width: 14, height: 14)
        case .some(false): Circle().strokeBorder(sky.inkColor.color.opacity(0.18), lineWidth: 1.5).frame(width: 14, height: 14)
        case .none: Color.clear.frame(width: 14, height: 14)
        }
    }
}
