import SwiftUI

/// v2 home: the day as an Orbit under a living sky, with the Light Column below.
struct DayView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.haloReferenceDate) private var referenceDate
    @Environment(\.haloScreenshotMode) private var fixture
    @Environment(\.haloReduceMotion) private var reduceMotion
    @State private var celebration = 0
    @State private var beadTaps = 0

    var body: some View {
        TimelineView(.everyMinute) { context in
            content(now: referenceDate ?? context.date)
        }
        // Load the month being viewed whenever it changes — from paging, swiping or a deep link.
        .onChange(of: Calendar.current.dateInterval(of: .month, for: model.selectedDate)?.start) { _, _ in
            if !fixture { Task { await model.refresh() } }
        }
        .fullScreenCover(isPresented: Binding(get: { model.showFocus }, set: { model.showFocus = $0 })) {
            FocusModeView()
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let day = model.viewedDay.map { calendar.startOfDay(for: $0) } ?? today
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
                    ZoomScaleBar(level: model.dayZoom, sky: sky) { zoom(to: $0) }
                    switch model.dayZoom {
                    case .day:
                        OrbitDial(scene: scene, sky: sky, style: model.settings.skyID.orbitStyle, now: now, habits: model.habits, events: events,
                                  celebration: celebration,
                                  onEvent: { id in model.selectedEvent = events.first { $0.id == id } },
                                  onBead: { id in toggle(id, scene: scene) },
                                  onNow: { if scene.isToday { model.showFocus = true } },
                                  onSwipe: { step in changeDay(from: day, by: step, now: now) })
                            .id(scene.day)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                            .padding(.horizontal, DS.Space.l)
                        if model.isSample {
                            Button { Task { await model.requestCalendar() } } label: {
                                Label("Sample day · Connect calendar", systemImage: "calendar.badge.plus")
                            }
                            .buttonStyle(GlassPillStyle(sky: sky))
                            .accessibilityIdentifier("connect-calendar")
                        }
                        if !scene.allDay.isEmpty { allDay(scene.allDay, sky: sky) }
                    case .week:
                        WeekStrip(week: ZoomBuilder.week(containing: day, now: now, events: model.events, habits: model.habits, calendar: calendar),
                                  selected: day, sky: sky, nowHour: scene.orbit.nowHour ?? OrbitGeometry.hours(of: now, calendar: calendar),
                                  onSelect: { picked in select(picked, now: now, then: .day) },
                                  onPage: { step in select(calendar.date(byAdding: .day, value: 7 * step, to: day)!, now: now) })
                        .padding(.horizontal, DS.Space.l)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                    case .month:
                        MonthGrid(rows: ZoomBuilder.month(containing: day, now: now, events: model.events, habits: model.habits, calendar: calendar),
                                  month: day, selected: day, sky: sky, nowHour: OrbitGeometry.hours(of: now, calendar: calendar),
                                  onSelect: { picked in
                                      if calendar.isDate(picked, inSameDayAs: day) { zoom(to: .day) } else { select(picked, now: now) }
                                  },
                                  onPage: { step in page(from: day, by: step, now: now) })
                            .padding(.horizontal, DS.Space.l)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                    LightColumn(scene: scene, sky: sky, now: now, focus: model.focus,
                                onEvent: { model.selectedEvent = $0 }, onFocus: { model.showFocus = true })
                        .padding(.horizontal, DS.Space.xl)
                }
                .padding(.bottom, DS.Space.hero)
            }
            .scrollIndicators(.hidden)
            .simultaneousGesture(MagnifyGesture().onEnded { value in
                if value.magnification < 0.8 { zoom(to: model.dayZoom.zoomedOut) }
                else if value.magnification > 1.25 { zoom(to: model.dayZoom.zoomedIn) }
            })
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
            if model.viewedDay != nil {
                Button("Today") { withAnimation(DS.Motion.resolve(DS.Motion.standard, reduceMotion: reduceMotion)) { model.viewedDay = nil } }
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

    private func changeDay(from day: Date, by step: Int, now: Date) {
        select(Calendar.current.date(byAdding: .day, value: step, to: day)!, now: now)
    }

    private func zoom(to level: ZoomLevel) {
        guard level != model.dayZoom else { return }
        withAnimation(DS.Motion.resolve(DS.Motion.morph, reduceMotion: reduceMotion)) { model.dayZoom = level }
    }

    /// Shows `date` (nil when it is today), optionally zooming, and loads its month if needed.
    private func select(_ date: Date, now: Date, then level: ZoomLevel? = nil) {
        let calendar = Calendar.current
        withAnimation(DS.Motion.resolve(DS.Motion.standard, reduceMotion: reduceMotion)) {
            model.viewedDay = calendar.isDate(date, inSameDayAs: now) ? nil : date
            if let level { model.dayZoom = level }
        }
        ensureLoaded(date)
    }

    private func page(from day: Date, by step: Int, now: Date) {
        let calendar = Calendar.current
        let month = calendar.dateInterval(of: .month, for: day)!.start
        let target = calendar.date(byAdding: .month, value: step, to: month)!
        // Paging back into the current month lands on today, not the 1st.
        select(calendar.isDate(target, equalTo: now, toGranularity: .month) ? now : target, now: now)
    }

    /// Points the model at the viewed month; the `.onChange` above refreshes when the month changes.
    private func ensureLoaded(_ date: Date) {
        guard !Calendar.current.isDate(date, equalTo: model.selectedDate, toGranularity: .month) else { return }
        model.selectedDate = date
    }
}
