import SwiftUI

struct RitualRow: View {
    var habit: Habit
    var date: Date = .now
    var onDetail: () -> Void
    var onToggle: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onDetail) {
                HStack(spacing: 12) {
                    Image(systemName: habit.icon)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(palette.accentInk)
                        .frame(width: 36, height: 36)
                        .background(palette.accentSoft, in: Circle())
                    VStack(alignment: .leading, spacing: 5) {
                        Text(habit.title)
                            .haloFont(.headline)
                            .foregroundStyle(palette.ink)
                        HStack(spacing: 4) {
                            Image(systemName: "sparkle")
                            RollingNumber(value: habit.streak(asOf: date))
                            Text("day streak")
                        }
                        .haloFont(.caption)
                        .foregroundStyle(palette.ink2)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(PressableStyle())
            RitualCheck(
                completed: habit.isCompleted(on: date),
                label: String(localized: "Complete \(habit.title)"),
                feedbackEnabled: false,
                action: onToggle
            )
            .accessibilityIdentifier("habit-check-\(habit.id.uuidString)")
        }
        .padding(.vertical, 6)
    }
}

struct RitualDailyHero: View {
    var habits: [Habit]
    var date: Date = .now
    var celebrating = false
    private let done: Int
    private let summary: RitualSummary
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.haloReduceMotion) private var reduceMotion

    init(habits: [Habit], date: Date = .now, celebrating: Bool = false) {
        self.habits = habits
        self.date = date
        self.celebrating = celebrating
        done = habits.filter { $0.isCompleted(on: date) }.count
        summary = RitualSummary(habits: habits, date: date)
    }

    var body: some View {
        let layout = dynamicType.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
            : AnyLayout(HStackLayout(spacing: 24))
        layout {
            ProgressRing(progress: Double(done) / Double(max(1, habits.count)), segments: max(1, habits.count))
                .frame(width: 120, height: 120)
                .overlay {
                    HStack(spacing: 2) {
                        RollingNumber(value: done)
                        Text("/")
                        RollingNumber(value: habits.count)
                    }
                    .haloFont(.numericM)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                }
                .shadow(color: palette.accent.opacity(celebrating ? 0.3 : 0), radius: 24)
                .scaleEffect(celebrating && !reduceMotion ? 1.04 : 1)
                .animation(reduceMotion ? nil : Motion.bouncy, value: celebrating)

            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey(done == habits.count && !habits.isEmpty ? "Beautifully kept." : "One small thing at a time."))
                    .haloFont(.displayS)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 5) {
                    Image(systemName: "sparkle")
                    RollingNumber(value: summary.streak)
                    Text("Day streak")
                }
                .haloFont(.footnote)
                .foregroundStyle(palette.ink2)
            }
        }
        .padding(.vertical, 12)
    }
}

#Preview("Ritual rows · Light") {
    DesignPreview {
        VStack(spacing: 24) {
            RitualDailyHero(habits: MockData.habits)
            RitualRow(habit: MockData.habits[0], onDetail: {}, onToggle: {})
        }
    }
}

#Preview("Ritual rows · Emerald AX3 Reduced Motion") {
    DesignPreview(themeID: "emeraldRitual", scheme: .dark, accessibility: true, reduceMotion: true) {
        RitualDailyHero(habits: [], celebrating: true)
    }
}

private struct RitualSummary {
    let streak: Int

    init(habits: [Habit], date: Date) {
        guard !habits.isEmpty else { streak = 0; return }
        let calendar = Calendar.current
        var counts: [Date: Int] = [:]
        for habit in habits {
            for day in Set(habit.completedDates.map { calendar.startOfDay(for: $0) }) {
                counts[day, default: 0] += 1
            }
        }
        var day = calendar.startOfDay(for: date)
        let threshold = Int(ceil(Double(habits.count) * 0.8))
        if counts[day, default: 0] < threshold { day = calendar.date(byAdding: .day, value: -1, to: day)! }
        var total = 0
        while counts[day, default: 0] >= threshold {
            total += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        streak = total
    }
}
