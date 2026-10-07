import SwiftUI

/// "Your week": seven mini-orbits woven into one ring, focus time at its centre, three numbers and one sentence.
struct WeekRecapView: View {
    var recap: WeekRecap
    var sky: SkyState

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.l) {
            Text("Your week").font(DS.Typeface.title(22, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
            GeometryReader { proxy in
                let size = min(proxy.size.width, proxy.size.height)
                let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                let radius = size * 0.37
                ZStack {
                    Circle()
                        .stroke(sky.inkColor.color.opacity(0.1), lineWidth: 1)
                        .frame(width: radius * 2, height: radius * 2)
                        .position(center)
                    ForEach(Array(recap.days.enumerated()), id: \.element.id) { index, mini in
                        let angle = -Double.pi / 2 + Double(index) * 2 * .pi / 7
                        VStack(spacing: 2) {
                            ZStack {
                                MiniOrbit(mini: mini, sky: sky, nowHour: nil)
                                Text(mini.day, format: .dateTime.day())
                                    .font(.caption2.weight(mini.isToday ? .bold : .regular))
                                    .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                            }
                            .frame(width: size * 0.2, height: size * 0.2)
                            Text(mini.day, format: .dateTime.weekday(.narrow))
                                .font(.caption2)
                                .opacity(SkyEngine.secondaryOpacity)
                                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                        }
                        .position(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                    }
                    VStack(spacing: 2) {
                        Text(focusText)
                            .font(DS.Typeface.clock(size * 0.11))
                        Text("focused").font(DS.Typeface.moment(size * 0.05)).opacity(SkyEngine.secondaryOpacity)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: size * 0.42)
                    .position(center)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 340)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
            ViewThatFits {
                HStack(alignment: .top) { stats }
                VStack(alignment: .leading, spacing: DS.Space.m) { stats }
            }
            Text(recap.sentence)
                .font(DS.Typeface.moment(18, relativeTo: .body))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Space.l)
        .haloGlass(RoundedRectangle(cornerRadius: DS.Radius.glass, style: .continuous), tint: sky.mid.color)
    }

    /// Under an hour reads as minutes (25′), like the rest of Halo Day; longer spans read 3h 20m.
    private var focusText: String {
        recap.focusMinutes < 60 ? "\(recap.focusMinutes)′"
            : Duration.seconds(recap.focusMinutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }

    @ViewBuilder
    private var stats: some View {
        stat(value: focusText, label: "Focus")
        stat(value: recap.ritualRate.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "–", label: "Rituals")
        stat(value: recap.busiestHour.flatMap { Calendar.current.date(bySettingHour: $0, minute: 0, second: 0, of: .now) }
                .map { $0.formatted(date: .omitted, time: .shortened) } ?? "–", label: "Busiest")
    }

    private func stat(value: String, label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: value).font(.title3.weight(.semibold).monospacedDigit())
            Text(label).font(.footnote).opacity(SkyEngine.secondaryOpacity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(value == "–" ? Text("Not enough yet") : Text(verbatim: value))
    }
}
