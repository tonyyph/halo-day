import SwiftUI

struct TodayRitualTiles: View {
    var habits: [Habit]
    var date: Date
    var onToggle: (Habit) -> Void
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicType

    var body: some View {
        let done = habits.filter { $0.isCompleted(on: date) }.count
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Rituals").haloFont(.displayM)
                Spacer()
                Text("\(done) / \(habits.count)").haloFont(.caption).monospacedDigit()
                    .contentTransition(.numericText()).foregroundStyle(palette.ink2)
            }
            if dynamicType.isAccessibilitySize {
                VStack(spacing: 12) {
                    ForEach(habits) { habit in
                        HStack {
                            Button(habit.title) { onToggle(habit) }.haloFont(.subhead).frame(minHeight: 44)
                            Spacer()
                            RitualCheck(completed: habit.isCompleted(on: date), feedbackEnabled: false) { onToggle(habit) }
                        }
                    }
                }
            } else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        ForEach(habits) { habit in
                            Button { onToggle(habit) } label: {
                                VStack(spacing: 10) {
                                    Image(systemName: habit.icon)
                                        .font(.title3)
                                        .foregroundStyle(palette.accentInk)
                                        .frame(width: 46, height: 46)
                                        .background(palette.accentSoft, in: Circle())
                                    Text(habit.title)
                                        .haloFont(.subhead)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .frame(minHeight: 38)
                                    RitualCheck(completed: habit.isCompleted(on: date), feedbackEnabled: false) { }
                                        .allowsHitTesting(false).accessibilityHidden(true)
                                }
                                .frame(width: 110)
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityLabel(Text("Complete \(habit.title)"))
                            .accessibilityValue(habit.isCompleted(on: date) ? Text("Completed") : Text("Not completed"))
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

struct TodayFocusEntry: View {
    var minutes: Int
    var onOpen: () -> Void
    var onStart: (Int) -> Void
    @Environment(\.palette) private var palette
    @Environment(\.haloHapticsEnabled) private var haptics
    @State private var playTrigger = 0

    var body: some View {
        HaloCard(hero: true) {
            HStack(spacing: 16) {
                Button(action: onOpen) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Focus").haloFont(.displayS)
                        Text("Start \(minutes) min").haloFont(.footnote).foregroundStyle(palette.ink2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PressableStyle())
                Button {
                    playTrigger += 1
                    onStart(minutes)
                } label: {
                    Image(systemName: "play.fill").foregroundStyle(palette.accentOn)
                        .frame(width: 44, height: 44).background(palette.accent, in: Circle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(Text("Start \(minutes) min"))
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: playTrigger) { _, _ in haptics }
    }
}

struct TodayHaloPreview: View {
    var preset: WidgetPreset
    var date: Date
    var events: [CalendarEvent]
    var habits: [Habit]
    var focus: FocusSession?
    var countdown: Countdown?
    var sample: Bool
    var onEdit: () -> Void
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicType

    var body: some View {
        Button(action: onEdit) {
            let layout = dynamicType.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 16)) : AnyLayout(HStackLayout(spacing: 16))
            HaloCard {
                layout {
                    PhonePreview(preset: preset, events: events, habits: habits, focus: focus,
                                 countdown: countdown, date: date, sample: sample)
                        .scaleEffect(0.42).frame(width: 108, height: 190)
                        .allowsHitTesting(false).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Halo").haloFont(.displayM)
                        Text(preset.name).haloFont(.subhead).foregroundStyle(palette.ink2)
                        Label("Edit", systemImage: "arrow.up.right").haloFont(.subhead).foregroundStyle(palette.accentInk)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Your Halo")
        .accessibilityIdentifier("today-halo-preview")
    }
}

#Preview("Today components · Pearl") {
    DesignPreview {
        VStack(spacing: 24) {
            TodayRitualTiles(habits: MockData.habits, date: .now, onToggle: { _ in })
            TodayFocusEntry(minutes: 50, onOpen: {}, onStart: { _ in })
        }
    }
}

#Preview("Today components · Gold Empty AX3") {
    DesignPreview(themeID: "midnightGold", scheme: .dark, accessibility: true, reduceMotion: true) {
        TodayRitualTiles(habits: [], date: .now, onToggle: { _ in })
    }
}
