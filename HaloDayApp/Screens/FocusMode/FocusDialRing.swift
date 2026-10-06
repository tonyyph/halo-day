import SwiftUI

enum FocusDialMath {
    /// Degrees clockwise from 12 o'clock, 0..<360.
    static func angle(of point: CGPoint, center: CGPoint) -> Double {
        var degrees = atan2(point.x - center.x, -(point.y - center.y)) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        return degrees
    }
    /// One full turn is 60 minutes; the raw value is clamped to 5...240 and carries laps across 12 o'clock.
    static func advance(_ raw: Double, from old: Double, to new: Double) -> Double {
        var delta = new - old
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return min(240, max(5, raw + delta / 6))
    }
    static func snapped(_ raw: Double) -> Int { Int((raw / 5).rounded()) * 5 }
    static func step(_ minutes: Int, by delta: Int) -> Int { min(240, max(5, minutes + delta)) }
}

/// Arc from 12 o'clock clockwise; animatable so countdowns can run on a single linear animation.
struct FocusArc: Shape {
    var fraction: Double
    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: min(rect.width, rect.height) / 2,
                        startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * min(1, max(0, fraction))), clockwise: false)
        }
    }
}

/// Turn the knob around the ring to choose 5–240 minutes (one turn = an hour).
struct FocusDialRing: View {
    @Binding var minutes: Int
    var sky: SkyState
    @State private var raw: Double?
    @State private var lastAngle: Double?

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let inset = size * 0.12
            let lap = minutes % 60 == 0 ? 1 : Double(minutes % 60) / 60
            ZStack {
                Circle().fill(RadialGradient(colors: [sky.glow.color.opacity(0.32), .clear], center: .center, startRadius: 0, endRadius: size / 2))
                Circle().stroke(sky.inkColor.color.opacity(0.14), lineWidth: size * 0.04).padding(inset)
                FocusArc(fraction: lap)
                    .stroke(sky.glow.color, style: StrokeStyle(lineWidth: size * 0.04, lineCap: .round))
                    .padding(inset)
                Circle().fill(.white)
                    .frame(width: size * 0.09, height: size * 0.09)
                    .shadow(color: sky.glow.color, radius: 10)
                    .offset(y: -(size / 2 - inset))
                    .rotationEffect(.degrees(lap * 360))
                VStack(spacing: 2) {
                    Text(verbatim: "\(minutes)")
                        .font(DS.Typeface.clock(size * 0.22))
                        .contentTransition(.numericText(value: Double(minutes)))
                    Text("minutes").font(DS.Typeface.moment(size * 0.06)).opacity(SkyEngine.secondaryOpacity)
                    if minutes >= 60 {
                        HStack(spacing: 4) {
                            ForEach(0..<(minutes / 60), id: \.self) { _ in Circle().frame(width: 5, height: 5) }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let angle = FocusDialMath.angle(of: value.location, center: CGPoint(x: size / 2, y: size / 2))
                    if let lastAngle {
                        let next = FocusDialMath.advance(raw ?? Double(minutes), from: lastAngle, to: angle)
                        raw = next
                        minutes = FocusDialMath.snapped(next)
                    }
                    lastAngle = angle
                }
                .onEnded { _ in lastAngle = nil; raw = nil })
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .animation(DS.Motion.standard, value: minutes)
        .sensoryFeedback(.selection, trigger: minutes)
        .accessibilityElement()
        .accessibilityLabel(Text("Focus length"))
        .accessibilityValue(Text("\(minutes) min"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: minutes = FocusDialMath.step(minutes, by: 5)
            case .decrement: minutes = FocusDialMath.step(minutes, by: -5)
            @unknown default: break
            }
        }
        .accessibilityIdentifier("focus-dial")
    }
}

/// The running countdown: one linear animation from the remaining fraction to zero, sun riding the arc's end.
struct FocusCountdownRing: View {
    var session: FocusSession
    var now: Date
    var sky: SkyState
    @State private var fraction: Double = 1
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.haloReferenceDate) private var referenceDate

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let inset = size * 0.12
            ZStack {
                Circle().fill(RadialGradient(colors: [sky.glow.color.opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: size / 2))
                Circle().stroke(sky.inkColor.color.opacity(0.14), lineWidth: size * 0.04).padding(inset)
                FocusArc(fraction: fraction)
                    .stroke(sky.glow.color, style: StrokeStyle(lineWidth: size * 0.04, lineCap: .round))
                    .padding(inset)
                Circle().fill(.white)
                    .frame(width: size * 0.07, height: size * 0.07)
                    .shadow(color: sky.glow.color, radius: 12)
                    .offset(y: -(size / 2 - inset))
                    .rotationEffect(.degrees(360 * fraction))
                VStack(spacing: 4) {
                    Group {
                        if session.isPaused {
                            Text(Duration.seconds(session.remaining(at: now)), format: .time(pattern: .minuteSecond))
                        } else {
                            Text(timerInterval: now...max(now, session.endDate), countsDown: true)
                        }
                    }
                    .font(DS.Typeface.clock(size * 0.17))
                    .monospacedDigit()
                    Text("until \(session.endDate.formatted(date: .omitted, time: .shortened))")
                        .font(DS.Typeface.moment(size * 0.055))
                        .opacity(SkyEngine.secondaryOpacity)
                }
            }
            .frame(width: size, height: size)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear(perform: sync)
        .onChange(of: session) { _, _ in sync() }
        // Animation time stops while the phone sleeps; resync with the clock when the app comes back.
        .onChange(of: scenePhase) { _, phase in if phase == .active { sync() } }
        .accessibilityElement(children: .combine)
    }

    private func sync() {
        let total = Double(max(1, session.durationMinutes) * 60)
        let remaining = session.remaining(at: referenceDate ?? .now)
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) { fraction = remaining / total }
        guard !session.isPaused, remaining > 0 else { return }
        withAnimation(.linear(duration: remaining)) { fraction = 0 }
    }
}
