import SwiftUI

struct TodayView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.haloNavigation) private var navigation
    @Environment(\.haloReferenceDate) private var referenceDate
    @Environment(\.haloScreenshotMode) private var fixture
    @Environment(\.haloReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var collapsed = false
    @State private var clockDate = Date.now
    @State private var activePreset = WidgetPreset(name: String(localized: "My Halo"))
    @State private var refreshing = false

    private var date: Date { referenceDate ?? clockDate }
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: date)
        let key = (5..<12).contains(hour) ? "Good morning" : (12..<18).contains(hour) ? "Good afternoon"
            : (18..<23).contains(hour) ? "Good evening" : "Still up"
        let value = String(localized: String.LocalizationValue(key))
        return model.settings.firstName.isEmpty ? value + "." : value + ", " + model.settings.firstName + "."
    }

    var body: some View {
        let events = model.events(on: date)
        HaloScreen(onScrollCollapse: { value in
            withAnimation(Motion.resolve(Motion.smooth, reduceMotion: reduceMotion)) { collapsed = value }
        }) {
            header.haloEntrance(0, appeared: appeared)
            if model.isSample { sampleBanner }
            TodayProgressHero().haloEntrance(1, appeared: appeared)

            TodayNextEvent(events: events, tomorrow: model.events(on: date.addingTimeInterval(86400)), date: date, fixedDate: referenceDate != nil) { event in
                open(event, source: "today-next-\(event.id)")
            } onCountdown: { event in Task { await model.countDown(event) } }
            .haloEntrance(2, appeared: appeared)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Today").haloFont(.displayM)
                    Spacer()
                    Button("See all") { model.tab = 1 }.haloFont(.subhead).frame(minHeight: 44)
                }
                if !events.isEmpty {
                    AgendaTimeline(events: events, date: date, fixedDate: referenceDate) { event, source in
                        open(event, source: source)
                    }
                }
            }
            .haloEntrance(3, appeared: appeared)

            TodayRitualTiles(habits: model.habits, date: date) { habit in
                withAnimation(Motion.resolve(Motion.snappy, reduceMotion: reduceMotion)) {
                    HaloViewActions.toggle(habit, model: model, date: date, fixture: fixture)
                }
            }
            .haloEntrance(4, appeared: appeared)

            TodayFocusEntry(minutes: model.focusHistory.first?.durationMinutes ?? 50) {
                model.tab = 4
            } onStart: { minutes in
                navigation?.focusSource = "focus-today"
                model.tab = 4
                Task { await model.startFocus(title: "", minutes: minutes) }
            }
            .haloZoomSource("focus-today")
            .haloEntrance(5, appeared: appeared)

            TodayHaloPreview(preset: activePreset, date: date, events: events, habits: model.habits,
                             focus: model.focus, countdown: model.countdowns.first, sample: model.isSample) {
                withAnimation(Motion.resolve(Motion.smooth, reduceMotion: reduceMotion)) { model.tab = 2 }
            }
            .haloEntrance(6, appeared: appeared)
        }
        .toolbar {
            ToolbarItem(placement: .principal) { Text(greeting).haloFont(.headline).opacity(collapsed ? 1 : 0) }
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.showSettings = true } label: { Image(systemName: "gearshape").frame(width: 44, height: 44) }
                    .accessibilityLabel("Settings")
            }
        }
        .overlay(alignment: .top) { DelayedShimmer(loading: refreshing, height: 3).allowsHitTesting(false) }
        .refreshable {
            refreshing = true
            if !fixture { await model.refresh() }
            refreshing = false
        }
        .onAppear { appeared = true; updatePreset() }
        .onChange(of: model.presets) { _, _ in updatePreset() }
        .onChange(of: model.theme.id) { _, _ in updatePreset() }
        .animation(Motion.resolve(Motion.smooth, reduceMotion: reduceMotion), value: events)
        .task(id: model.events) {
            guard referenceDate == nil else { return }
            let future = model.todayEvents.flatMap { [$0.startDate, $0.endDate] }.filter { $0 > .now }.sorted()
            for boundary in future {
                let clock = ContinuousClock()
                try? await Task.sleep(until: clock.now.advanced(by: .seconds(max(0, boundary.timeIntervalSinceNow))), clock: clock)
                guard !Task.isCancelled else { return }
                clockDate = .now
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(date, format: .dateTime.weekday(.wide).day().month(.wide))
                .captionUpper().foregroundStyle(palette.ink2)
            Text(greeting).haloFont(.displayL).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
        .opacity(collapsed ? 0 : 1)
        .blur(radius: collapsed && !reduceMotion ? 2 : 0)
    }

    private var sampleBanner: some View {
        HaloCard(variant: .inset) {
            VStack(alignment: .leading, spacing: 8) {
                Text("A sample day").haloFont(.headline)
                Text("Connect your calendar to see your own events.").haloFont(.footnote).foregroundStyle(palette.ink2)
                Button("Connect") { Task { await model.requestCalendar() } }.frame(minHeight: 44)
            }
        }
    }

    private func open(_ event: CalendarEvent, source: String) {
        navigation?.eventSource = source
        model.selectedEvent = event
    }

    private func updatePreset() {
        let id = AppGroupStorage.shared.read("activePreset", fallback: "")
        activePreset = (fixture ? model.presets.first : model.presets.first { $0.id.uuidString == id })
            ?? WidgetPreset(name: String(localized: "My Halo"), themeId: model.theme.id)
    }
}

#Preview("Today · Pearl") {
    TodayView().environment(HaloModel()).haloTheme(ThemeRegistry.theme("pearlHalo"))
}

#Preview("Today · Ruby Dark AX3") {
    TodayView().environment(HaloModel()).haloTheme(ThemeRegistry.theme("rubyGlass"))
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility3)
        .environment(\.haloReduceMotionOverride, true)
}
