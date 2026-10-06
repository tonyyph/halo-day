import SwiftUI

/// Seven bars of light for the week's focus, and the latest sessions.
struct FocusHistoryView: View {
    var recap: WeekRecap
    var sessions: [FocusSession]
    var sky: SkyState

    var body: some View {
        let peak = max(30, recap.focusMinutesByDay.max() ?? 0)
        let bar = OrbitPalette.ritualColor(sky: sky)
        VStack(alignment: .leading, spacing: DS.Space.m) {
            Text("Focus").font(DS.Typeface.title(22, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
            HStack(alignment: .bottom, spacing: DS.Space.s) {
                ForEach(Array(zip(recap.days, recap.focusMinutesByDay)), id: \.0.id) { mini, minutes in
                    VStack(spacing: DS.Space.xs) {
                        Capsule()
                            .fill(LinearGradient(colors: [bar, bar.opacity(0.35)], startPoint: .top, endPoint: .bottom))
                            .frame(height: max(4, 96 * CGFloat(minutes) / CGFloat(peak)))
                        Text(mini.day, format: .dateTime.weekday(.narrow))
                            .font(.caption2)
                            .opacity(SkyEngine.secondaryOpacity)
                            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                    }
                    .frame(maxWidth: .infinity, alignment: .bottom)
                    .accessibilityElement()
                    .accessibilityLabel(Text(mini.day, format: .dateTime.weekday(.wide)))
                    .accessibilityValue(Text("\(minutes) min"))
                }
            }
            .frame(height: 124, alignment: .bottom)
            if sessions.isEmpty {
                Text("Your focus sessions will gather here.").font(.footnote).opacity(SkyEngine.secondaryOpacity)
            } else {
                VStack(spacing: DS.Space.s) {
                    ForEach(sessions) { session in
                        HStack {
                            Text(session.title).lineLimit(1)
                            Spacer()
                            Text(session.startDate, format: .dateTime.day().month(.abbreviated)).opacity(SkyEngine.secondaryOpacity)
                            Text("\(max(1, Int(session.endDate.timeIntervalSince(session.startDate) / 60))) min")
                                .monospacedDigit()
                        }
                        .font(.footnote)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .padding(DS.Space.l)
        .haloGlass(RoundedRectangle(cornerRadius: DS.Radius.glass, style: .continuous), tint: sky.mid.color)
    }
}
