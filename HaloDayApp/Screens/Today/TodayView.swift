import SwiftUI

struct TodayView: View {
    @Environment(HaloModel.self) private var model
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let key = (5..<12).contains(hour) ? "Good morning" : (12..<18).contains(hour) ? "Good afternoon" : (18..<23).contains(hour) ? "Good evening" : "Still up"
        let value = String(localized: String.LocalizationValue(key))
        return model.settings.firstName.isEmpty ? value + "." : value + ", " + model.settings.firstName + "."
    }
    var body: some View {
        HaloScreen {
            VStack(alignment: .leading, spacing: HaloTokens.Space.small) {
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide)).textCase(.uppercase).font(.caption.weight(.semibold)).tracking(1.2).foregroundStyle(.secondary)
                Text(greeting).font(HaloTokens.display)
            }
            if model.isSample {
                HaloCard {
                    HStack {
                        VStack(alignment: .leading, spacing: HaloTokens.Space.tiny) {
                            Text("A sample day").font(.headline)
                            Text("Connect your calendar to see your own events.").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Connect") { Task { await model.requestCalendar() } }.font(.subheadline)
                    }
                }
            }
            HaloCard {
                HStack(spacing: HaloTokens.Space.card) {
                    ProgressRing(progress: model.progress).overlay { Text(model.progress, format: .percent.precision(.fractionLength(0))).font(.caption.bold()) }.frame(width: 65, height: 65)
                    VStack(alignment: .leading, spacing: HaloTokens.Space.small) {
                        Text("Day progress").font(.headline)
                        Text("\(model.completedHabits) of \(model.habits.count) rituals kept").font(.subheadline).foregroundStyle(.secondary)
                        ProgressView(value: model.progress)
                    }
                }
            }
            if let event = model.nextEvent {
                Button { model.selectedEvent = event } label: {
                    HaloCard(hero: true) {
                        VStack(alignment: .leading, spacing: HaloTokens.Space.row) {
                            Label(event.startDate <= .now ? "NOW" : "UP NEXT", systemImage: "circle.fill").font(.caption2.bold()).tracking(1.2).foregroundStyle(.tint)
                            Text(event.title).font(HaloTokens.display).multilineTextAlignment(.leading)
                            HStack { Text(event.startDate, style: .time); Text("–"); Text(event.endDate, style: .time) }.font(.subheadline.monospacedDigit())
                            Label(event.location ?? event.calendarName, systemImage: event.location == nil ? "calendar" : "mappin").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }.buttonStyle(.plain)
            } else {
                HaloCard { EmptyState(title: "An open day", message: "Nothing on the calendar. Make room for something good.") }
            }
            HStack { Text("Today").font(HaloTokens.title); Spacer(); Button("See all") { model.tab = 1 }.font(.subheadline) }
            HaloCard {
                VStack(spacing: 0) {
                    ForEach(model.todayEvents) { event in
                        Button { model.selectedEvent = event } label: { AgendaRow(event: event) }.buttonStyle(.plain)
                    }
                }
            }
            HStack { Text("Rituals").font(HaloTokens.title); Spacer(); Text("\(model.completedHabits) / \(model.habits.count)").font(.caption).foregroundStyle(.secondary) }
            ForEach(model.habits.prefix(3)) { habit in
                Button { model.toggleHabit(habit) } label: {
                    HaloCard {
                        HStack {
                            Image(systemName: habit.isCompleted() ? "checkmark.circle.fill" : habit.icon).foregroundStyle(.tint)
                            Text(habit.title).font(.subheadline)
                            Spacer()
                            Image(systemName: habit.isCompleted() ? "checkmark" : "circle").foregroundStyle(.secondary)
                        }.frame(minHeight: 24)
                    }
                }.buttonStyle(.plain)
            }
            Button { model.tab = 4 } label: {
                HaloCard { HStack { Label("Make space to focus", systemImage: "timer").font(HaloTokens.title); Spacer(); Image(systemName: "arrow.up.right") } }
            }.buttonStyle(.plain)
            Button { model.tab = 2 } label: {
                HaloCard {
                    VStack(spacing: HaloTokens.Space.card) {
                        HStack { Text("Your Halo").font(HaloTokens.title); Spacer(); Text("Edit").font(.subheadline).foregroundStyle(.tint) }
                        HaloWidgetContent(date: .now, type: .agenda, size: .rectangular, theme: model.theme, events: model.todayEvents, habits: model.habits, focus: model.focus, countdown: model.countdowns.first, sample: model.isSample).frame(height: 70)
                        Text("Your day, beautifully on display.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.buttonStyle(.plain)
        }.toolbar { ToolbarItem(placement: .topBarTrailing) { Button { model.showSettings = true } label: { Image(systemName: "gearshape") }.accessibilityLabel("Settings") } }
            .refreshable { await model.refresh() }
    }
}
#Preview { TodayView().environment(HaloModel()) }
