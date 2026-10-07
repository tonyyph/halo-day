import SwiftUI

/// "Your week", set like a page from a fine almanac: one large figure, a ribbon of seven slender days
/// (calendar load in shadow, focus in champagne, rituals as pearls), three numbers and one sentence.
struct WeekRecapView: View {
    var recap: WeekRecap
    var sky: SkyState

    /// Champagne gold: bright on dark skies, deepened on light ones so it keeps its contrast.
    private var gold: Color {
        (sky.ink == .light ? SkyColor(hex: 0xE2C391) : SkyColor(hex: 0x8C6A3A)).color
    }
    private var ink: Color { sky.inkColor.color }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xl) {
            header
            hero
            ribbon
                .frame(height: 150)
                .accessibilityHidden(true)
            hairline
            ViewThatFits {
                HStack(alignment: .top, spacing: 0) { stats(divided: true) }
                VStack(alignment: .leading, spacing: DS.Space.m) { stats(divided: false) }
            }
            closing
        }
        .padding(DS.Space.xl)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [ink.opacity(sky.ink == .light ? 0.02 : 0.03), ink.opacity(sky.ink == .light ? 0.08 : 0.06)],
                                     startPoint: .top, endPoint: .bottom))
        }
        .haloGlass(RoundedRectangle(cornerRadius: 28, style: .continuous), tint: sky.mid.color)
        .overlay {
            // A hairline of gold that catches the light at the corners.
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(LinearGradient(colors: [gold.opacity(0.9), gold.opacity(0.12), gold.opacity(0.12), gold.opacity(0.7)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.75)
        }
    }

    // MARK: Parts

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            smallCaps(String(localized: "The week"))
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel(Text("Your week"))
            Spacer()
            if let first = recap.days.first?.day, let last = recap.days.last?.day {
                smallCaps((first..<last).formatted(.interval.day().month(.abbreviated)))
            }
        }
        .foregroundStyle(gold)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text(verbatim: focusText)
                .font(DS.Typeface.display(60, relativeTo: .largeTitle).weight(.light))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("of focus")
                .font(DS.Typeface.moment(19, relativeTo: .title3))
                .foregroundStyle(gold)
        }
        .accessibilityElement(children: .combine)
    }

    /// Seven slender columns: the calendar's weight as a soft shadow, focus as a rising line of gold.
    private var ribbon: some View {
        let maxFocus = max(60, recap.focusMinutesByDay.max() ?? 0)
        return HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(recap.days.enumerated()), id: \.element.id) { index, day in
                let focus = recap.focusMinutesByDay.indices.contains(index) ? recap.focusMinutesByDay[index] : 0
                VStack(spacing: DS.Space.s) {
                    GeometryReader { proxy in
                        let height = proxy.size.height
                        ZStack(alignment: .bottom) {
                            Capsule().fill(ink.opacity(0.08)).frame(width: 2)
                            Capsule().fill(ink.opacity(0.18))
                                .frame(width: 8, height: max(8, height * min(1, day.busyHours / 12)))
                            if focus > 0 {
                                Capsule()
                                    .fill(LinearGradient(colors: [gold, gold.opacity(0.55)], startPoint: .top, endPoint: .bottom))
                                    .frame(width: 8, height: max(8, height * Double(focus) / Double(maxFocus)))
                                    .shadow(color: gold.opacity(0.5), radius: 6)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .overlay(alignment: .top) {
                            if day.isToday {
                                Circle().fill(gold).frame(width: 5, height: 5).shadow(color: gold, radius: 4)
                            }
                        }
                    }
                    HStack(spacing: 3) {
                        ForEach(0..<min(day.ritualsTotal, 3), id: \.self) { pearl in
                            Circle()
                                .fill(pearl < day.ritualsDone ? gold : ink.opacity(0.18))
                                .frame(width: 4, height: 4)
                        }
                    }
                    .frame(height: 4)
                    VStack(spacing: 1) {
                        Text(day.day, format: .dateTime.weekday(.narrow))
                            .font(.system(size: 10, weight: .semibold)).tracking(1.2)
                            .opacity(SkyEngine.secondaryOpacity)
                        Text(day.day, format: .dateTime.day())
                            .font(DS.Typeface.title(15, relativeTo: .footnote))
                            .foregroundStyle(day.isToday ? gold : ink)
                    }
                    .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var hairline: some View {
        Rectangle()
            .fill(LinearGradient(colors: [gold.opacity(0), gold.opacity(0.6), gold.opacity(0)], startPoint: .leading, endPoint: .trailing))
            .frame(height: 0.5)
    }

    private var closing: some View {
        VStack(spacing: DS.Space.m) {
            HStack(spacing: DS.Space.s) {
                Rectangle().fill(gold.opacity(0.5)).frame(width: 28, height: 0.5)
                Image(systemName: "sparkle").font(.system(size: 8)).foregroundStyle(gold)
                Rectangle().fill(gold.opacity(0.5)).frame(width: 28, height: 0.5)
            }
            .accessibilityHidden(true)
            Text(recap.sentence)
                .font(DS.Typeface.moment(19, relativeTo: .body))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Numbers

    /// Under an hour reads as minutes (25′), like the rest of Halo Day; longer spans read 3h 20m.
    private var focusText: String {
        recap.focusMinutes < 60 ? "\(recap.focusMinutes)′"
            : Duration.seconds(recap.focusMinutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }

    @ViewBuilder
    private func stats(divided: Bool) -> some View {
        stat(value: focusText, label: "Focus")
        if divided { divider }
        stat(value: recap.ritualRate.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "–", label: "Rituals")
        if divided { divider }
        stat(value: recap.busiestHour.flatMap { Calendar.current.date(bySettingHour: $0, minute: 0, second: 0, of: .now) }
                .map { $0.formatted(date: .omitted, time: .shortened) } ?? "–", label: "Busiest")
    }

    private var divider: some View {
        Rectangle().fill(gold.opacity(0.35)).frame(width: 0.5, height: 40).padding(.horizontal, DS.Space.m)
    }

    private func stat(value: String, label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text(verbatim: value)
                .font(DS.Typeface.title(24, relativeTo: .title2).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .semibold)).tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(gold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(value == "–" ? Text("Not enough yet") : Text(verbatim: value))
    }

    private func smallCaps(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(2)
            .textCase(.uppercase)
    }
}
