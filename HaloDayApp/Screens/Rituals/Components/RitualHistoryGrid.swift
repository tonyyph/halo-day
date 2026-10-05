import SwiftUI

struct RitualHistory {
    let days: [Bool]
    let bestStreak: Int
    let completionRate: Double

    init(habit: Habit, date: Date = .now) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        days = (0..<84).map { index in
            let day = calendar.date(byAdding: .day, value: index - 83, to: today)!
            return habit.isCompleted(on: day)
        }
        completionRate = Double(days.suffix(30).filter { $0 }.count) / 30
        let dates = Set(habit.completedDates.map { calendar.startOfDay(for: $0) }).sorted()
        var best = 0
        var current = 0
        var previous: Date?
        for day in dates {
            current = previous.map { calendar.dateComponents([.day], from: $0, to: day).day == 1 } == true
                ? current + 1 : 1
            best = max(best, current)
            previous = day
        }
        bestStreak = best
    }
}

struct RitualHistoryGrid: View {
    var days: [Bool]
    private let completed: Int
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion
    @State private var appeared = false

    init(days: [Bool]) {
        self.days = days
        completed = days.filter { $0 }.count
    }

    var body: some View {
        let values = days
        let accent = palette.accent
        let track = palette.surfaceSunken
        return Group {
            if reduceMotion { Self.grid(values: values, accent: accent, track: track, reveal: 1) }
            else {
                Color.clear.keyframeAnimator(initialValue: 0.0, trigger: appeared) { _, reveal in
                    Self.grid(values: values, accent: accent, track: track, reveal: reveal)
                } keyframes: { _ in
                    CubicKeyframe(1, duration: 0.65)
                }
            }
        }
        .frame(height: 154)
        .onAppear { appeared = true }
        .accessibilityLabel("Last 12 weeks")
        .accessibilityValue(Text("\(completed) days completed"))
    }

    private nonisolated static func grid(values: [Bool], accent: Color, track: Color, reveal: Double) -> some View {
        Canvas { context, size in
            let gap: CGFloat = 4
            let cell = min((size.width - 11 * gap) / 12, (size.height - 6 * gap) / 7)
            let origin = (size.width - 12 * cell - 11 * gap) / 2
            for index in values.indices {
                let column = index / 7
                let row = index % 7
                let alpha = min(1, max(0, reveal * 2 - Double(column + row) / 18))
                let rect = CGRect(
                    x: origin + CGFloat(column) * (cell + gap),
                    y: CGFloat(row) * (cell + gap), width: cell, height: cell
                )
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 3),
                    with: .color((values[index] ? accent : track).opacity(alpha))
                )
            }
        }
    }
}

struct RitualDetailView: View {
    var habit: Habit
    var onEdit: () -> Void
    private let history: RitualHistory
    @Environment(\.dismiss) private var dismiss

    init(habit: Habit, onEdit: @escaping () -> Void) {
        self.habit = habit
        self.onEdit = onEdit
        history = RitualHistory(habit: habit)
    }

    var body: some View {
        NavigationStack {
            HaloScreen {
                SectionTitle(title: habit.title)
                Text("Last 12 weeks").captionUpper().foregroundStyle(.secondary)
                RitualHistoryGrid(days: history.days)
                HaloCard {
                    VStack(alignment: .leading, spacing: 16) {
                        statistic("Current streak", value: habit.streakCount)
                        statistic("Best streak", value: history.bestStreak)
                        HStack {
                            Text("Completion rate")
                            Spacer()
                            Text(history.completionRate, format: .percent.precision(.fractionLength(0)))
                                .contentTransition(.numericText())
                        }
                    }
                }
                HaloButton(title: "Edit", action: onEdit)
            }
            .toolbar { Button("Close") { dismiss() } }
        }
    }

    private func statistic(_ title: String, value: Int) -> some View {
        HStack {
            Text(LocalizedStringKey(title))
            Spacer()
            RollingNumber(value: value).haloFont(.numericM)
        }
    }
}

#Preview("History · Emerald Dark") {
    DesignPreview(themeID: "emeraldRitual", scheme: .dark) {
        RitualHistoryGrid(days: (0..<84).map { $0.isMultiple(of: 3) })
    }
}

#Preview("History · Empty AX3 Reduced Motion") {
    DesignPreview(accessibility: true, reduceMotion: true) {
        RitualHistoryGrid(days: Array(repeating: false, count: 84))
    }
}
