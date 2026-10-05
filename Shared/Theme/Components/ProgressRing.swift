import SwiftUI

struct ProgressRing: View {
    var progress: Double
    var width: CGFloat = 7
    var segments: Int = 1

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        GeometryReader { geometry in
            let value = appeared ? min(1, max(0, progress)) : 0
            ZStack {
                Circle()
                    .stroke(palette.hairline, lineWidth: width)

                if segments > 1 {
                    ForEach(0..<segments, id: \.self) { index in
                        let start = Double(index) / Double(segments) + 0.004
                        let end = Double(index + 1) / Double(segments) - 0.004
                        Circle()
                            .trim(from: start, to: max(start, min(end, value)))
                            .stroke(palette.accent, style: StrokeStyle(lineWidth: width, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                } else {
                    Circle()
                        .trim(from: 0, to: value)
                        .stroke(
                            AngularGradient(colors: [palette.accent, palette.accent.opacity(0.7), palette.accent], center: .center),
                            style: StrokeStyle(lineWidth: width, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }

                if value > 0 && segments == 1 {
                    Circle()
                        .fill(palette.accent)
                        .frame(width: width, height: width)
                        .shadow(color: palette.accent.opacity(0.45), radius: width)
                        .offset(y: -(geometry.size.height - width) / 2)
                        .rotationEffect(.degrees(value * 360))
                }
            }
            .padding(width / 2)
        }
        .animation(Motion.resolve(Motion.ring, reduceMotion: reduceMotion), value: progress)
        .animation(Motion.resolve(Motion.ring, reduceMotion: reduceMotion), value: appeared)
        .onAppear { appeared = true }
        .accessibilityLabel(Text("Progress"))
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}

struct RollingNumber: View {
    var value: Int
    var suffix: String = ""

    var body: some View {
        Text("\(value)\(suffix)")
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(value)))
    }
}

#Preview("Ring · Light") {
    ProgressRing(progress: 0.72)
        .frame(width: 120, height: 120)
        .padding()
}

#Preview("Ring · AX3 / Dark") {
    ProgressRing(progress: 0.6, segments: 5)
        .frame(width: 120, height: 120)
        .padding()
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
}
