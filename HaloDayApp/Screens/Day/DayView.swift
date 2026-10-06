import SwiftUI

/// v2 home: the day as an Orbit under a living sky, with the Light Column below.
struct DayView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.haloReferenceDate) private var referenceDate
    @Environment(\.haloScreenshotMode) private var fixture
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dayOffset = 0
    @State private var celebration = 0
    @State private var beadTaps = 0

    var body: some View {
        TimelineView(.everyMinute) { context in
            content(now: referenceDate ?? context.date)
        }
        .fullScreenCover(isPresented: Binding(get: { model.showFocus }, set: { model.showFocus = $0 })) {
            FocusModeView()
        }
        .onAppear { if model.focus?.isActive == true { model.showFocus = true } }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let day = calendar.date(byAdding: .day, value: dayOffset, to: today)!
        let coordinate = model.skyCoordinate
        let sky = SkyEngine.state(sky: model.settings.skyID, at: day.addingTimeInterval(now.timeIntervalSince(today)), coordinate: coordinate, calendar: calendar)
        let events = model.events(on: day)
        let scene = DaySceneBuilder.build(day: day, now: now, events: events, habits: model.habits, focusSessions: model.focusSessions,
                                          solar: SolarCalculator.day(containing: day, coordinate: coordinate, calendar: calendar), calendar: calendar)
        ZStack {
            SkyBackground(state: sky)
            ScrollView {
                VStack(spacing: DS.Space.xl) {
                    header(scene, sky: sky)
                    OrbitDial(scene: scene, sky: sky, style: model.settings.skyID.orbitStyle, now: now, habits: model.habits, events: events,
                              celebration: celebration,
                              onEvent: { id in model.selectedEvent = events.first { $0.id == id } },
                              onBead: { id in toggle(id, scene: scene) },
                              onNow: { if scene.isToday { model.showFocus = true } },
                              onSwipe: { step in changeDay(by: step, now: now) })
                        .id(scene.day)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .padding(.horizontal, DS.Space.l)
                    if model.isSample {
                        Button { Task { await model.requestCalendar() } } label: {
                            Label("Sample day · Connect calendar", systemImage: "calendar.badge.plus")
                        }
                        .buttonStyle(GlassPillStyle(sky: sky))
                        .accessibilityIdentifier("connect-calendar")
                    }
                    if !scene.allDay.isEmpty { allDay(scene.allDay, sky: sky) }
                    LightColumn(scene: scene, sky: sky, now: now, focus: model.focus,
                                onEvent: { model.selectedEvent = $0 }, onFocus: { model.showFocus = true })
                        .padding(.horizontal, DS.Space.xl)
                }
                .padding(.bottom, DS.Space.hero)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(sky.inkColor.color)
        .tint(sky.inkColor.color)
        .environment(\.colorScheme, sky.ink == .light ? .dark : .light)
        .toolbarColorScheme(sky.ink == .light ? .dark : .light, for: .tabBar)
        .animation(DS.Motion.resolve(DS.Motion.inkFlip, reduceMotion: reduceMotion), value: sky.ink)
        .sensoryFeedback(.impact(weight: .light), trigger: beadTaps) { _, _ in model.settings.haptics }
        .sensoryFeedback(.success, trigger: celebration) { _, _ in model.settings.haptics }
    }

    private func header(_ scene: DayScene, sky: SkyState) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text(scene.day, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(DS.Typeface.title(22, relativeTo: .title2))
                    .accessibilityAddTraits(.isHeader)
                Text(summary(scene)).font(.subheadline).opacity(SkyEngine.secondaryOpacity)
            }
            Spacer()
            if dayOffset != 0 {
                Button("Today") { withAnimation(DS.Motion.resolve(DS.Motion.standard, reduceMotion: reduceMotion)) { dayOffset = 0 } }
                    .buttonStyle(GlassPillStyle(sky: sky))
            }
        }
        .padding(.horizontal, DS.Space.xl)
        .padding(.top, DS.Space.l)
    }

    private func summary(_ scene: DayScene) -> String {
        var parts = [String(localized: "\(scene.ritualsDone)/\(scene.ritualsTotal) rituals")]
        if scene.focusMinutes > 0 { parts.append(String(localized: "\(scene.focusMinutes)′ focused")) }
        return parts.joined(separator: " · ")
    }

    private func allDay(_ events: [CalendarEvent], sky: SkyState) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: DS.Space.s) {
                ForEach(events) { event in
                    Button { model.selectedEvent = event } label: {
                        Text(event.title).font(.footnote.weight(.medium)).padding(.horizontal, DS.Space.m).frame(minHeight: 32)
                    }
                    .haloGlass(Capsule(), tint: sky.mid.color)
                }
            }
            .padding(.horizontal, DS.Space.xl)
        }
        .scrollIndicators(.hidden)
    }

    private func toggle(_ id: UUID, scene: DayScene) {
        guard scene.isToday, let habit = model.habits.first(where: { $0.id == id }) else { return }
        let wasComplete = scene.ritualsTotal > 0 && scene.ritualsDone == scene.ritualsTotal
        withAnimation(DS.Motion.resolve(DS.Motion.standard, reduceMotion: reduceMotion)) {
            HaloViewActions.toggle(habit, model: model, date: scene.day, fixture: fixture)
        }
        beadTaps += 1
        let done = model.habits.filter { $0.isCompleted(on: scene.day) }.count
        if !wasComplete, done > 0, done == model.habits.count { celebration += 1 }
    }

    private func changeDay(by step: Int, now: Date) {
        withAnimation(DS.Motion.resolve(DS.Motion.standard, reduceMotion: reduceMotion)) { dayOffset += step }
        let target = Calendar.current.date(byAdding: .day, value: dayOffset, to: now)!
        if !Calendar.current.isDate(target, equalTo: model.selectedDate, toGranularity: .month) {
            model.selectedDate = target
            if !fixture { Task { await model.refresh() } }
        }
    }
}
