import SwiftUI

/// The opening moment: the static launch colour melts into the real sky, the Orbit draws itself from noon
/// with the sun (or moon) at the current hour, the wordmark rises, and the whole scene opens into the app.
struct SplashView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.haloReduceMotion) private var reduceMotion
    var onFinish: () -> Void

    @State private var launchCover = 1.0
    @State private var ring = 0.0
    @State private var trail = 1.0
    @State private var sun = false
    @State private var wordmark = false
    @State private var leaving = false
    private let now = Date.now

    var body: some View {
        let sky = SkyEngine.state(sky: model.settings.skyID, at: now, coordinate: model.skyCoordinate)
        ZStack {
            SkyBackground(state: sky)
            // The static launch screen, faded away so the hand-off from iOS has no hard cut.
            Color("LaunchSky").opacity(launchCover)
            VStack(spacing: DS.Space.xxl) {
                orbit(sky: sky)
                    .frame(width: 220, height: 220)
                    .scaleEffect(leaving ? 1.18 : 1)
                VStack(spacing: DS.Space.s) {
                    Text(verbatim: "Halo Day")
                        .font(DS.Typeface.display(44))
                        .tracking(0.5)
                    Text("Your day, as a ring of light.")
                        .font(DS.Typeface.moment(17))
                        .opacity(SkyEngine.secondaryOpacity)
                }
                .opacity(wordmark ? 1 : 0)
                .offset(y: wordmark ? 0 : 14)
                .blur(radius: wordmark ? 0 : 6)
            }
            .foregroundStyle(sky.inkColor.color)
            .offset(y: -20)
        }
        .opacity(leaving ? 0 : 1)
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Halo Day"))
        .task { await play() }
    }

    private func orbit(sky: SkyState) -> some View {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: now)
        let content = OrbitContent(
            layout: OrbitLayout(day: day, events: model.events(on: day), calendar: calendar),
            beads: DaySceneBuilder.beads(for: model.habits, on: day),
            nightSpans: OrbitGeometry.nightSpans(SolarCalculator.day(containing: day, coordinate: model.skyCoordinate, calendar: calendar), calendar: calendar),
            nowHour: sun ? OrbitGeometry.hours(of: now, calendar: calendar) : nil,
            moonPhase: SolarCalculator.moonPhase(at: now))
        let metrics = OrbitMetrics(size: 220)
        return ZStack {
            OrbitCanvas(content: content, sky: sky, style: model.settings.skyID.orbitStyle, breathing: false)
                .opacity(ring)
                .scaleEffect(0.92 + 0.08 * ring)
            // A comet of light runs once round the track from noon, clockwise like the day, and the Orbit appears behind it.
            Circle()
                .trim(from: max(0, ring - 0.3), to: ring)
                .stroke(AngularGradient(colors: [sky.glow.color.opacity(0), sky.glow.color], center: .center,
                                        startAngle: .degrees(360 * (ring - 0.3)), endAngle: .degrees(360 * ring)),
                        style: StrokeStyle(lineWidth: metrics.trackWidth, lineCap: .round))
                .frame(width: metrics.radius * 2, height: metrics.radius * 2)
                .rotationEffect(.degrees(-90))
                .shadow(color: sky.glow.color, radius: 10)
                .opacity(trail)
        }
    }

    private func play() async {
        if reduceMotion {
            ring = 1; trail = 0; sun = true; wordmark = true; launchCover = 0
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.easeOut(duration: 0.3)) { leaving = true }
            try? await Task.sleep(for: .milliseconds(300))
            onFinish()
            return
        }
        withAnimation(.easeOut(duration: 0.45)) { launchCover = 0 }
        withAnimation(.timingCurve(0.6, 0, 0.25, 1, duration: 1.1).delay(0.1)) { ring = 1 }
        try? await Task.sleep(for: .milliseconds(1100))
        withAnimation(.easeOut(duration: 0.4)) { trail = 0 }
        withAnimation(.spring(duration: 0.5, bounce: 0.35)) { sun = true }
        withAnimation(.easeOut(duration: 0.6).delay(0.1)) { wordmark = true }
        try? await Task.sleep(for: .milliseconds(1000))
        withAnimation(.easeIn(duration: 0.45)) { leaving = true }
        try? await Task.sleep(for: .milliseconds(450))
        onFinish()
    }
}
