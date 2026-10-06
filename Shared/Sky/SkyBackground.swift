import SwiftUI

/// Full-bleed sky: three-stop gradient, a soft glow where the light comes from, and fixed (seeded) stars.
struct SkyBackground: View {
    var state: SkyState

    var body: some View {
        ZStack {
            LinearGradient(stops: [
                .init(color: state.top.color, location: 0),
                .init(color: state.mid.color, location: 0.5),
                .init(color: state.bottom.color, location: 1)
            ], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [state.glow.color.opacity(state.isNight ? 0.18 : 0.35), .clear],
                           center: UnitPoint(x: 0.5, y: 0.28), startRadius: 0, endRadius: 360)
            if state.stars > 0.01 {
                Canvas { context, size in
                    var generator = SeededGenerator(seed: 7)
                    for _ in 0..<110 {
                        let point = CGPoint(x: .random(in: 0...size.width, using: &generator), y: .random(in: 0...(size.height * 0.75), using: &generator))
                        let radius = CGFloat.random(in: 0.3...1.1, using: &generator)
                        let alpha = Double.random(in: 0.2...0.85, using: &generator) * state.stars
                        context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                                     with: .color(.white.opacity(alpha)))
                    }
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Deterministic PRNG so stars don't jump between renders.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
