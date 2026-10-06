import SwiftUI

/// The interactive Orbit: tap beads/arcs/now, hold for focus, swipe to change day.
/// Every interactive element also has an invisible 44 pt button for VoiceOver and UI tests.
struct OrbitDial: View {
    var scene: DayScene
    var sky: SkyState
    var style: OrbitStyle
    var now: Date
    var habits: [Habit]
    var events: [CalendarEvent]
    var celebration: Int
    var onEvent: (String) -> Void
    var onBead: (UUID) -> Void
    var onNow: () -> Void
    var onSwipe: (Int) -> Void
    @State private var drawn: CGFloat = 0
    @State private var glow: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let metrics = OrbitMetrics(size: size)
            ZStack {
                OrbitCanvas(content: scene.orbit, sky: sky, style: style, breathing: scene.isToday)
                Circle()
                    .trim(from: 0, to: drawn)
                    .stroke(sky.glow.color, style: StrokeStyle(lineWidth: metrics.trackWidth * 0.45, lineCap: .round))
                    .frame(width: (metrics.radius + metrics.trackWidth * 2.4) * 2, height: (metrics.radius + metrics.trackWidth * 2.4) * 2)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: sky.glow.color, radius: 10)
                    .opacity(glow)
                    .allowsHitTesting(false)
                center(size: size)
                targets(metrics: metrics)
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .onTapGesture { location in tap(location, metrics: metrics) }
            .onLongPressGesture(minimumDuration: 0.45) { onNow() }
            .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { value in
                let dx = value.translation.width, dy = value.translation.height
                if abs(dx) > 60, abs(dx) > abs(dy) * 1.5 { onSwipe(dx < 0 ? 1 : -1) }
            })
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .onChange(of: celebration) { _, _ in celebrate() }
    }

    private func center(size: CGFloat) -> some View {
        VStack(spacing: size * 0.012) {
            if scene.isToday {
                Text(now, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                    .font(DS.Typeface.clock(size * 0.15))
                Text(sky.moment.title).font(DS.Typeface.moment(size * 0.055)).opacity(SkyEngine.secondaryOpacity)
            } else {
                Text(scene.day, format: .dateTime.day()).font(DS.Typeface.clock(size * 0.17))
                Text(scene.day, format: .dateTime.weekday(.wide)).font(DS.Typeface.moment(size * 0.055)).opacity(SkyEngine.secondaryOpacity)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(width: size * 0.44)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func targets(metrics: OrbitMetrics) -> some View {
        if let hour = scene.orbit.nowHour {
            target(at: OrbitGeometry.point(forHour: hour, radius: metrics.radius, center: metrics.center), action: onNow)
                .accessibilityLabel(Text("Now. Start focus"))
                .accessibilityIdentifier("orbit-now")
        }
        ForEach(scene.orbit.layout.arcs) { arc in
            let event = events.first { $0.id == arc.id }
            target(at: OrbitGeometry.point(forHour: (arc.start + arc.end) / 2, radius: metrics.laneRadius(arc.lane), center: metrics.center)) { onEvent(arc.id) }
                .accessibilityLabel(Text(event.map { "\($0.title), \($0.startDate.formatted(date: .omitted, time: .shortened))" } ?? ""))
                .accessibilityIdentifier("arc-\(arc.id)")
        }
        ForEach(scene.orbit.beads) { bead in
            target(at: OrbitGeometry.point(forHour: bead.hour, radius: metrics.beadRadius, center: metrics.center)) { onBead(bead.id) }
                .accessibilityLabel(Text(habits.first { $0.id == bead.id }?.title ?? ""))
                .accessibilityValue(bead.isDone ? Text("Done") : Text("Not done"))
                .accessibilityIdentifier("bead-\(bead.id.uuidString)")
        }
    }

    private func target(at point: CGPoint, action: @escaping () -> Void) -> some View {
        Button(action: action) { Color.clear.frame(width: 44, height: 44).contentShape(Circle()) }
            .buttonStyle(.plain)
            .position(point)
    }

    private func tap(_ location: CGPoint, metrics: OrbitMetrics) {
        switch OrbitGeometry.hitTest(location, metrics: metrics, layout: scene.orbit.layout, beads: scene.orbit.beads, nowHour: scene.orbit.nowHour) {
        case .now: onNow()
        case let .bead(id): onBead(id)
        case let .arc(id): onEvent(id)
        case nil: break
        }
    }

    private func celebrate() {
        if reduceMotion {
            drawn = 1
            glow = 1
            withAnimation(.easeOut(duration: 0.6).delay(0.8)) { glow = 0 }
            return
        }
        drawn = 0
        glow = 1
        withAnimation(.easeInOut(duration: 0.9)) { drawn = 1 }
        withAnimation(.easeOut(duration: 0.8).delay(1.1)) { glow = 0 }
    }
}
