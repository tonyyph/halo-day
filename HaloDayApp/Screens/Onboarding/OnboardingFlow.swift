import SwiftUI

/// A suggested first ritual.
struct StarterRitual: Identifiable, Hashable {
    var id: String
    var title: String
    var icon: String
    var color: String
    var time: TimeOfDay

    static let all: [StarterRitual] = [
        StarterRitual(id: "water", title: String(localized: "Drink water"), icon: "drop", color: Habit.palette[2], time: .morning),
        StarterRitual(id: "meditate", title: String(localized: "Meditate"), icon: "wind", color: Habit.palette[4], time: .morning),
        StarterRitual(id: "move", title: String(localized: "A little movement"), icon: "figure.walk", color: Habit.palette[3], time: .afternoon),
        StarterRitual(id: "read", title: String(localized: "Read a few pages"), icon: "book.closed", color: Habit.palette[0], time: .evening),
        StarterRitual(id: "skin", title: String(localized: "Skin care"), icon: "sparkles", color: Habit.palette[1], time: .evening),
        StarterRitual(id: "journal", title: String(localized: "A page of journaling"), icon: "pencil.line", color: Habit.palette[5], time: .evening)
    ]
    var habit: Habit { Habit(title: title, icon: icon, accentColor: color, timeOfDay: time) }
}

/// v2 onboarding: Dawn → Calendar → Rituals → Your sky. The sky and Orbit carry every step.
struct OnboardingFlow: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.haloScreenshotMode) private var fixture
    @Environment(\.haloReferenceDate) private var referenceDate
    @Environment(\.haloReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var picked: [String] = []
    @State private var busy = false
    @State private var locating = false
    @State private var appeared = Date.now

    private let dawnLength: TimeInterval = 6

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: step != 0 || reduceMotion)) { context in
            let now = referenceDate ?? .now
            let progress = step == 0 && !reduceMotion ? min(1, context.date.timeIntervalSince(appeared) / dawnLength) : 1
            let sky = SkyEngine.state(sky: model.settings.skyID, at: skyDate(progress: progress, now: now), coordinate: model.skyCoordinate)
            ZStack {
                SkyBackground(state: sky)
                VStack(spacing: DS.Space.xl) {
                    topBar(sky)
                    orbit(sky: sky, now: now, progress: progress)
                        .frame(maxWidth: 280)
                    copy
                    Spacer(minLength: 0)
                    actions(sky)
                }
                .padding(.horizontal, DS.Space.xl)
                .padding(.vertical, DS.Space.l)
            }
            .foregroundStyle(sky.inkColor.color)
            .tint(sky.inkColor.color)
            .environment(\.colorScheme, sky.ink == .light ? .dark : .light)
            .animation(DS.Motion.resolve(DS.Motion.standard, reduceMotion: reduceMotion), value: step)
        }
        .onAppear { appeared = .now }
    }

    /// The dawn step runs the sky from 04:30 to now in a few seconds.
    private func skyDate(progress: Double, now: Date) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        var target = OrbitGeometry.hours(of: now, calendar: calendar)
        if target < 4.5 { target += 24 }
        return start.addingTimeInterval((4.5 + (target - 4.5) * progress) * 3600)
    }

    private func topBar(_ sky: SkyState) -> some View {
        HStack {
            if step > 0 {
                Button { step -= 1 } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    .haloGlass(Circle(), tint: sky.mid.color)
                    .accessibilityLabel(Text("Back"))
                    .accessibilityIdentifier("onboarding-back")
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule().frame(width: index == step ? 18 : 6, height: 6).opacity(index == step ? 1 : 0.35)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Text("Step \(step + 1) of 4"))
        }
        .frame(height: 44)
    }

    private func orbit(sky: SkyState, now: Date, progress: Double) -> some View {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: now)
        let rituals = step >= 2 ? StarterRitual.all.filter { picked.contains($0.id) }.map(\.habit) : []
        let content = OrbitContent(layout: OrbitLayout(day: day, events: step >= 1 ? model.events(on: day) : [], calendar: calendar),
                                   beads: DaySceneBuilder.beads(for: rituals, on: day),
                                   nightSpans: OrbitGeometry.nightSpans(SolarCalculator.day(containing: day, coordinate: model.skyCoordinate, calendar: calendar), calendar: calendar),
                                   nowHour: step == 0 ? nil : OrbitGeometry.hours(of: now, calendar: calendar),
                                   moonPhase: SolarCalculator.moonPhase(at: now))
        return OrbitCanvas(content: content, sky: sky, style: model.settings.skyID.orbitStyle, breathing: step > 0)
            .mask { Circle().trim(from: 0, to: progress).stroke(lineWidth: 400).rotationEffect(.degrees(90)) }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var copy: some View {
        VStack(spacing: DS.Space.s) {
            Text(title).font(DS.Typeface.display(32, relativeTo: .largeTitle)).multilineTextAlignment(.center)
            Text(detail).font(.body).opacity(SkyEngine.secondaryOpacity).multilineTextAlignment(.center)
        }
        .fixedSize(horizontal: false, vertical: true)
        if step == 2 { ritualPicker }
    }

    private var title: String {
        switch step {
        case 0: String(localized: "Your day, as a ring of light.")
        case 1: String(localized: "Bring in your calendar")
        case 2: String(localized: "A few small rituals")
        default: String(localized: "Your sky")
        }
    }

    private var detail: String {
        switch step {
        case 0: String(localized: "Halo Day draws your day under the real sky — events, rituals and focus on one ring.")
        case 1: String(localized: "Your events become arcs on the Orbit and in your widgets. Everything stays on this iPhone.")
        case 2: String(localized: "Pick up to three. They sit on the Orbit at their time of day; tap one to keep it.")
        default: String(localized: "Match the sky to where you are, and get a gentle nudge before events. Both are optional.")
        }
    }

    private var ritualPicker: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: DS.Space.s), GridItem(.flexible(), spacing: DS.Space.s)], spacing: DS.Space.s) {
            ForEach(StarterRitual.all) { ritual in
                let selected = picked.contains(ritual.id)
                Button {
                    if selected { picked.removeAll { $0 == ritual.id } } else if picked.count < 3 { picked.append(ritual.id) }
                } label: {
                    HStack(spacing: DS.Space.s) {
                        Image(systemName: selected ? "checkmark.circle.fill" : ritual.icon).frame(width: 22)
                        Text(ritual.title).font(.subheadline.weight(selected ? .semibold : .regular)).lineLimit(2).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(DS.Space.m)
                    .frame(minHeight: 52)
                    .contentShape(RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous))
                    .background { if selected { RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous).fill(Color.primary.opacity(0.12)) } }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier("onboarding-ritual-\(ritual.id)")
            }
        }
    }

    @ViewBuilder
    private func actions(_ sky: SkyState) -> some View {
        VStack(spacing: DS.Space.m) {
            switch step {
            case 0:
                primary("Begin", sky: sky) { step = 1 }
            case 1:
                primary("Connect calendar", sky: sky) {
                    busy = true
                    if !fixture { await model.requestCalendar() }
                    busy = false
                    step = 2
                }
                Button("Use sample data") { step = 2 }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("onboarding-sample")
            case 2:
                primary("Continue", sky: sky) { step = 3 }
            default:
                Toggle(isOn: Binding(get: { locating || model.settings.approxCoordinate != nil }, set: { on in
                    guard !fixture, !locating else { return }
                    locating = on
                    Task { _ = await model.useLocationForSky(on); locating = false }
                })) { Label("Match the sky to my location", systemImage: "location") }
                .tint(OrbitPalette.ritualColor(sky: sky))
                .accessibilityIdentifier("onboarding-location")
                Toggle(isOn: Binding(get: { model.settings.notificationPermissionGranted }, set: { on in
                    guard on, !fixture else { return }
                    Task { await model.requestNotifications() }
                })) { Label("Remind me before events", systemImage: "bell") }
                .tint(OrbitPalette.ritualColor(sky: sky))
                .accessibilityIdentifier("onboarding-notifications")
                Button {
                    model.completeOnboarding(rituals: StarterRitual.all.filter { picked.contains($0.id) }.map(\.habit), fixture: fixture)
                } label: { Text("Start my day").font(.headline).frame(maxWidth: .infinity) }
                .buttonStyle(GlassPillStyle(sky: sky))
                .accessibilityIdentifier("onboarding-finish")
            }
        }
    }

    private func primary(_ title: LocalizedStringKey, sky: SkyState, action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            HStack { if busy { ProgressView() }; Text(title).font(.headline) }.frame(maxWidth: .infinity)
        }
        .buttonStyle(GlassPillStyle(sky: sky))
        .disabled(busy)
        .accessibilityIdentifier("onboarding-primary")
    }
}
