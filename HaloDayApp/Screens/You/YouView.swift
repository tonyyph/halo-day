import SwiftUI

struct RitualDraft: Identifiable {
    let id = UUID()
    var habit: Habit?
}

/// The "You" space: your week, rituals, focus, countdowns and Premium.
struct YouView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.haloScreenshotMode) private var fixture
    @State private var draft: RitualDraft?
    @State private var detail: Habit?
    @State private var addingCountdown = false

    var body: some View {
        SkyScreen { sky, now in
            let recap = WeekRecapBuilder.build(containing: now, now: now, events: model.events, habits: model.habits,
                                               focusSessions: model.focusSessions, calendar: .current)
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.xxl) {
                    Text("You").font(DS.Typeface.display(34, relativeTo: .largeTitle)).accessibilityAddTraits(.isHeader)
                    WeekRecapView(recap: recap, sky: sky)
                    rituals(sky: sky, now: now)
                    FocusHistoryView(recap: recap, sessions: Array(model.focusSessions.filter { !$0.isActive }.prefix(5)), sky: sky)
                    countdowns(sky: sky, now: now)
                    premium(sky: sky)
                }
                .padding(.horizontal, DS.Space.xl)
                .padding(.vertical, DS.Space.l)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.showSettings = true } label: { Image(systemName: "gearshape").frame(width: 44, height: 44) }
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("settings-open")
            }
        }
        .sheet(item: $draft) { RitualEditorView(habit: $0.habit) }
        .sheet(item: $detail) { RitualDetailView(habitID: $0.id) }
        .sheet(isPresented: $addingCountdown) { CountdownEditorView() }
    }

    private func header(_ title: LocalizedStringKey, action: LocalizedStringKey, id: String, sky: SkyState, perform: @escaping () -> Void) -> some View {
        ViewThatFits {
            HStack {
                Text(title).font(DS.Typeface.title(22, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: perform) { Label(action, systemImage: "plus") }.buttonStyle(GlassPillStyle(sky: sky)).accessibilityIdentifier(id)
            }
            VStack(alignment: .leading, spacing: DS.Space.s) {
                Text(title).font(DS.Typeface.title(22, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
                Button(action: perform) { Label(action, systemImage: "plus") }.buttonStyle(GlassPillStyle(sky: sky)).accessibilityIdentifier(id)
            }
        }
    }

    private func rituals(sky: SkyState, now: Date) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            header("Rituals", action: "New ritual", id: "ritual-new", sky: sky) { draft = RitualDraft() }
            if model.habits.isEmpty {
                Text("Small, daily things. A little water, a page, a walk.").opacity(SkyEngine.secondaryOpacity)
            }
            ForEach(model.habits) { habit in
                Button { detail = habit } label: { RitualLine(habit: habit, sky: sky, now: now) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("ritual-row-\(habit.id.uuidString)")
            }
        }
    }

    private func countdowns(sky: SkyState, now: Date) -> some View {
        let calendar = Calendar.current
        return VStack(alignment: .leading, spacing: DS.Space.m) {
            header("Countdowns", action: "Add countdown", id: "countdown-new", sky: sky) { addingCountdown = true }
            if model.countdowns.isEmpty {
                Text("Birthdays, trips, launches — count the days to what matters.").opacity(SkyEngine.secondaryOpacity)
            }
            ForEach(model.countdowns) { countdown in
                let days = max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: countdown.targetDate)).day ?? 0)
                HStack(spacing: DS.Space.l) {
                    ZStack {
                        Circle().stroke(sky.inkColor.color.opacity(0.14), lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: max(0.04, 1 - min(Double(days), 60) / 60))
                            .stroke(OrbitPalette.ritualColor(sky: sky), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text(verbatim: "\(days)").font(.headline.monospacedDigit())
                    }
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(countdown.title).font(.body.weight(.medium))
                        Text(countdown.targetDate, format: .dateTime.weekday(.wide).day().month(.wide).year())
                            .font(.footnote)
                            .opacity(SkyEngine.secondaryOpacity)
                    }
                    Spacer(minLength: 0)
                    Text("\(days) days left").font(.footnote).opacity(SkyEngine.secondaryOpacity)
                }
                .padding(DS.Space.m)
                .haloGlass(RoundedRectangle(cornerRadius: DS.Radius.glass, style: .continuous), tint: sky.mid.color)
                .contextMenu {
                    Button("Delete", role: .destructive) { HaloViewActions.removeCountdown(countdown, model: model, fixture: fixture) }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("countdown-row-\(countdown.id.uuidString)")
            }
        }
    }

    private func premium(sky: SkyState) -> some View {
        Button { model.showPaywall = true } label: {
            HStack(spacing: DS.Space.l) {
                Image(systemName: "sparkles").font(.title2).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.purchases.isPremium ? "Halo Day Premium" : "Upgrade to Premium").font(.headline)
                    Text("Every sky, unlimited rituals and focus on your Lock Screen.").font(.footnote).opacity(SkyEngine.secondaryOpacity)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote).accessibilityHidden(true)
            }
            .padding(DS.Space.l)
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.glass, style: .continuous))
            .haloGlass(RoundedRectangle(cornerRadius: DS.Radius.glass, style: .continuous), tint: sky.mid.color)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("you-premium")
    }
}
