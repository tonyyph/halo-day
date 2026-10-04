import SwiftUI

struct ThemeBackground: View {
    @Environment(\.haloTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        GeometryReader { geometry in
            let palette = theme.palette(scheme)
            Color(hex: palette.bg).overlay {
                RadialGradient(colors: [Color(hex: palette.halo), .clear], center: UnitPoint(x: 0.5, y: -0.1), startRadius: 0, endRadius: geometry.size.width * 0.9)
            }
        }.ignoresSafeArea()
    }
}
struct HaloCard<Content: View>: View {
    @Environment(\.haloTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var hero = false
    @ViewBuilder var content: Content
    var body: some View {
        let palette = theme.palette(scheme)
        let shape = RoundedRectangle(cornerRadius: hero ? HaloTokens.Radius.hero : HaloTokens.Radius.card, style: .continuous)
        content.frame(maxWidth: .infinity, alignment: .leading)
            .padding(hero ? HaloTokens.Space.hero : HaloTokens.Space.card)
            .background {
                if hero && !reduceTransparency { shape.fill(.ultraThinMaterial) }
                else { shape.fill(Color(hex: palette.surface)) }
            }
            .overlay(shape.stroke(Color(hex: palette.hairline), lineWidth: 0.5))
            .shadow(color: Color(hex: palette.shadowTint).opacity(scheme == .dark ? 0 : 0.06), radius: 12, y: 4)
    }
}
struct HaloButtonStyle: ButtonStyle {
    @Environment(\.haloTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        let palette = theme.palette(scheme)
        configuration.label.font(.headline).frame(maxWidth: .infinity).frame(minHeight: 54)
            .foregroundStyle(Color(hex: palette.accentOn))
            .background(Color(hex: palette.accent), in: Capsule())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
    }
}
struct ProgressRing: View {
    var progress: Double
    var width: CGFloat = 7
    var body: some View {
        ZStack {
            Circle().stroke(.primary.opacity(0.1), lineWidth: width)
            Circle().trim(from: 0, to: min(1, max(0, progress))).stroke(.tint, style: StrokeStyle(lineWidth: width, lineCap: .round)).rotationEffect(.degrees(-90))
        }.padding(width / 2).accessibilityLabel(Text("Progress")).accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}
struct PremiumChip: View {
    var preview = false
    var body: some View {
        Label(preview ? "Premium preview" : "Premium", systemImage: "sparkle")
            .font(.caption).padding(.horizontal, HaloTokens.Space.small).padding(.vertical, HaloTokens.Space.tiny)
            .background(.primary.opacity(0.08), in: Capsule())
    }
}
struct EmptyState: View {
    var icon = "sun.horizon"
    var title: String
    var message: String
    var body: some View {
        VStack(spacing: HaloTokens.Space.row) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(.tint)
            Text(LocalizedStringKey(title)).font(HaloTokens.title)
            Text(LocalizedStringKey(message)).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(HaloTokens.Space.major)
    }
}
struct AgendaRow: View {
    var event: CalendarEvent
    var date: Date = .now
    var body: some View {
        HStack(alignment: .top, spacing: HaloTokens.Space.row) {
            Group {
                if event.isAllDay { Text("All day") } else { Text(event.startDate, style: .time) }
            }.font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 65, alignment: .leading)
            Capsule().fill(Color(hex: event.accentColor)).frame(width: 3, height: 36)
            VStack(alignment: .leading, spacing: HaloTokens.Space.tiny) {
                Text(event.title).font(.headline)
                Text(event.location ?? event.calendarName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if event.endDate < date { Image(systemName: "checkmark").foregroundStyle(.secondary) }
            else if event.startDate <= date { Text("NOW").font(.caption2.bold()).foregroundStyle(.tint) }
        }.padding(.vertical, HaloTokens.Space.small)
    }
}
struct WeekStrip: View {
    @Binding var selected: Date
    var body: some View {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: selected)!.start
        HStack(spacing: HaloTokens.Space.tiny) {
            ForEach(0..<7) { offset in
                let day = calendar.date(byAdding: .day, value: offset, to: start)!
                Button { selected = day } label: {
                    VStack(spacing: HaloTokens.Space.small) {
                        Text(day, format: .dateTime.weekday(.narrow)).font(.caption)
                        Text(day, format: .dateTime.day()).font(.headline.monospacedDigit())
                    }.frame(maxWidth: .infinity).frame(minHeight: 64)
                        .background(calendar.isDate(day, inSameDayAs: selected) ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: HaloTokens.Radius.small))
                }.buttonStyle(.plain).accessibilityLabel(Text(day, format: .dateTime.weekday().month().day()))
            }
        }
    }
}
struct MiniMonthGrid: View {
    var month: Date
    var highlights: Set<Int> = []
    var selection: ((Date) -> Void)?
    var body: some View {
        let calendar = Calendar.current
        let first = calendar.dateInterval(of: .month, for: month)!.start
        let count = calendar.range(of: .day, in: .month, for: month)!.count
        let offset = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 6) {
            ForEach(0..<(count + offset), id: \.self) { index in
                if index < offset { Color.clear.frame(height: selection == nil ? 18 : 44) }
                else {
                    let number = index - offset + 1
                    let day = calendar.date(byAdding: .day, value: number - 1, to: first)!
                    if let selection {
                        Button { selection(day) } label: { dayCell(number, day: day).frame(minHeight: 44) }.buttonStyle(.plain)
                    } else { dayCell(number, day: day) }
                }
            }
        }
    }
    private func dayCell(_ number: Int, day: Date) -> some View {
        Text(number, format: .number).font(.caption.monospacedDigit()).frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .foregroundStyle(Calendar.current.isDateInToday(day) ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            .background(highlights.contains(number) ? Color.primary.opacity(0.08) : Color.clear, in: Capsule())
            .accessibilityLabel(Text(day, format: .dateTime.month().day()))
    }
}
