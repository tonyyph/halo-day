import SwiftUI

struct TodayView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.haloNavigation) private var navigation
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.haloReduceMotion) private var reduceMotion
    @State private var hasAppeared = false
    @State private var collapsed = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let key = (5..<12).contains(hour) ? "Good morning" :
            (12..<18).contains(hour) ? "Good afternoon" :
            (18..<23).contains(hour) ? "Good evening" : "Still up"
        let value = String(localized: String.LocalizationValue(key))
        return model.settings.firstName.isEmpty
            ? value + "." : value + ", " + model.settings.firstName + "."
    }

    var body: some View {
        HaloScreen(onScrollCollapse: { value in
            withAnimation(Motion.resolve(Motion.smooth, reduceMotion: reduceMotion)) { collapsed = value }
        }) {
            header.sectionEntrance(0, hasAppeared, reduceMotion)
            if model.isSample { sampleBanner }
            progress.sectionEntrance(1, hasAppeared, reduceMotion)
            nextEvent.sectionEntrance(2, hasAppeared, reduceMotion)
            timeline.sectionEntrance(3, hasAppeared, reduceMotion)
            rituals.sectionEntrance(4, hasAppeared, reduceMotion)
            focusEntry.sectionEntrance(5, hasAppeared, reduceMotion)
            haloPreview.sectionEntrance(6, hasAppeared, reduceMotion)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(greeting).haloFont(.headline).opacity(collapsed ? 1 : 0)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.showSettings = true } label: {
                    Image(systemName: "gearshape").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Settings")
            }
        }
        .refreshable { await model.refresh() }
        .onAppear { hasAppeared = true }
        .animation(Motion.resolve(Motion.smooth, reduceMotion: reduceMotion), value: model.todayEvents)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                .captionUpper()
                .foregroundStyle(palette.ink2)
            Text(greeting)
                .haloFont(.displayL)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
        .opacity(collapsed ? 0 : 1)
        .blur(radius: collapsed && !reduceMotion ? 2 : 0)
    }

    private var sampleBanner: some View {
        HaloCard(variant: .inset) {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock").foregroundStyle(palette.accentInk)
                VStack(alignment: .leading, spacing: 4) {
                    Text("A sample day").haloFont(.headline)
                    Text("Connect your calendar to see your own events.")
                        .haloFont(.footnote).foregroundStyle(palette.ink2)
                }
                Spacer(minLength: 4)
                Button("Connect") { Task { await model.requestCalendar() } }
                    .haloFont(.subhead)
            }
        }
    }

    private var progress: some View {
        let layout = dynamicType.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
            : AnyLayout(HStackLayout(spacing: 24))
        return layout {
            ProgressRing(progress: model.progress)
                .frame(width: 120, height: 120)
                .overlay {
                    Text(model.progress, format: .percent.precision(.fractionLength(0)))
                        .haloFont(.numericL)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            VStack(alignment: .leading, spacing: 8) {
                Text("Day progress")
                    .captionUpper()
                    .foregroundStyle(palette.ink2)
                    .accessibilityLabel("Day progress")
                Text("\(model.completedHabits) of \(model.habits.count) rituals kept")
                    .haloFont(.displayS)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Your day, beautifully on display.")
                    .haloFont(.footnote).foregroundStyle(palette.ink2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    @ViewBuilder private var nextEvent: some View {
        if let event = model.nextEvent {
            Button {
                navigation?.eventSource = "today-next-\(event.id)"
                model.selectedEvent = event
            } label: {
                HaloCard(hero: true) {
                    HStack(alignment: .top, spacing: 16) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(PaletteResolver.eventAccent(event.accentColor))
                            .frame(width: 3)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "circle.fill").font(.system(size: 6))
                                Text(event.startDate <= .now ? "NOW" : "UP NEXT").captionUpper()
                                Spacer()
                                if event.startDate > .now {
                                    Text(event.startDate, style: .relative)
                                        .haloFont(.footnote).foregroundStyle(palette.ink2)
                                }
                            }
                            .foregroundStyle(palette.accentInk)
                            Text(event.title)
                                .haloFont(.displayM)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 5) {
                                Text(event.startDate, style: .time)
                                Text("–")
                                Text(event.endDate, style: .time)
                            }
                            .font(HaloFont.subhead.monospacedDigit())
                            Label(event.location ?? event.calendarName,
                                  systemImage: event.location == nil ? "calendar" : "mappin")
                                .haloFont(.footnote)
                                .foregroundStyle(palette.ink2)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .buttonStyle(PressableStyle())
            .haloZoomSource("today-next-\(event.id)")
        } else {
            HaloCard(variant: .inset) {
                EmptyState(title: "An open day", message: "Nothing on the calendar. Make room for something good.")
            }
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today").haloFont(.displayM)
                Spacer()
                Button("See all") { model.tab = 1 }.haloFont(.subhead)
            }
            if !model.todayEvents.isEmpty {
                HaloCard {
                    VStack(spacing: 0) {
                        ForEach(Array(model.todayEvents.prefix(6))) { event in
                            Button {
                                navigation?.eventSource = "today-row-\(event.id)"
                                model.selectedEvent = event
                            } label: {
                                AgendaRow(event: event)
                            }
                            .buttonStyle(PressableStyle())
                            .haloZoomSource("today-row-\(event.id)")
                            if event.id != model.todayEvents.prefix(6).last?.id {
                                Divider().padding(.leading, 81)
                            }
                        }
                    }
                }
            }
        }
    }

    private var rituals: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rituals").haloFont(.displayM)
                Spacer()
                Text("\(model.completedHabits) / \(model.habits.count)")
                    .haloFont(.caption)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(palette.ink2)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(model.habits) { habit in
                        Button {
                            withAnimation(Motion.resolve(Motion.snappy, reduceMotion: reduceMotion)) {
                                model.toggleHabit(habit)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Image(systemName: habit.icon)
                                    .font(.title3)
                                    .foregroundStyle(palette.accentInk)
                                    .frame(width: 38, height: 38)
                                    .background(palette.accentSoft, in: Circle())
                                HStack(spacing: 8) {
                                    Text(habit.title).haloFont(.subhead).lineLimit(1)
                                    Image(systemName: habit.isCompleted() ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(palette.accentInk)
                                }
                            }
                            .frame(width: 128, alignment: .leading)
                            .padding(14)
                            .background(palette.surfaceSunken, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var focusEntry: some View {
        Button { model.tab = 4 } label: {
            HaloCard {
                HStack(spacing: 14) {
                    Image(systemName: "timer").font(.title2).foregroundStyle(palette.accentInk)
                    Text("Make space to focus").haloFont(.displayS)
                    Spacer()
                    Image(systemName: "play.fill")
                        .font(.footnote).foregroundStyle(palette.accentOn)
                        .frame(width: 38, height: 38)
                        .background(palette.accent, in: Circle())
                }
            }
        }
        .buttonStyle(PressableStyle())
    }

    private var haloPreview: some View {
        Button { model.tab = 2 } label: {
            HaloCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Your Halo").haloFont(.displayM)
                        Spacer()
                        Text("Edit").haloFont(.subhead).foregroundStyle(palette.accentInk)
                    }
                    HaloWidgetContent(
                        date: .now, type: .agenda, size: .rectangular,
                        theme: model.theme, events: model.todayEvents,
                        habits: model.habits, focus: model.focus,
                        countdown: model.countdowns.first, sample: model.isSample
                    )
                    .frame(height: 70)
                    Text("Your day, beautifully on display.")
                        .haloFont(.caption).foregroundStyle(palette.ink2)
                }
            }
        }
        .buttonStyle(PressableStyle())
    }
}

private struct SectionEntrance: ViewModifier {
    var index: Int
    var appeared: Bool
    var reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 12)
            .animation(Motion.resolve(Motion.stagger(index), reduceMotion: reduceMotion), value: appeared)
    }
}

private extension View {
    func sectionEntrance(_ index: Int, _ appeared: Bool, _ reduceMotion: Bool) -> some View {
        modifier(SectionEntrance(index: index, appeared: appeared, reduceMotion: reduceMotion))
    }
}

#Preview { TodayView().environment(HaloModel()) }
