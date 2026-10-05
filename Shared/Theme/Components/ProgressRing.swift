import SwiftUI

struct ProgressRing: View {
    var progress: Double
    var width: CGFloat = 7
    var segments: Int = 1
    var animates = true

    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion
    @Environment(\.haloWidgetContext) private var widgetContext
    @State private var appeared = false

    var body: some View {
        GeometryReader { geometry in
            let value = appeared || widgetContext ? min(1, max(0, progress)) : 0
            ZStack {
                if segments > 1 {
                    ForEach(0..<segments, id: \.self) { index in
                        let start = Double(index) / Double(segments) + 0.004
                        let end = Double(index + 1) / Double(segments) - 0.004
                        Circle()
                            .trim(from: start, to: end)
                            .stroke(palette.hairline, style: StrokeStyle(lineWidth: width, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Circle()
                            .trim(from: start, to: max(start, min(end, value)))
                            .stroke(palette.accent, style: StrokeStyle(lineWidth: width, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                } else {
                    Circle().stroke(palette.hairline, lineWidth: width)
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
                        .shadow(color: palette.accent.opacity(widgetContext ? 0 : 0.45), radius: width)
                        .offset(y: -(geometry.size.height - width) / 2)
                        .rotationEffect(.degrees(value * 360))
                }
            }
            .padding(width / 2)
        }
        .animation(animates && !reduceMotion && !widgetContext ? Motion.ring : nil, value: progress)
        .animation(animates && !reduceMotion && !widgetContext ? Motion.ring : nil, value: appeared)
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
