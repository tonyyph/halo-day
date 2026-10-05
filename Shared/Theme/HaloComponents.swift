import SwiftUI

struct ThemeBackground: View {
    @Environment(\.palette) private var palette
    var body: some View {
        palette.bg
            .overlay {
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        .init(0, 0), .init(0.5, 0), .init(1, 0),
                        .init(0, 0.5), .init(0.5, 0.5), .init(1, 0.5),
                        .init(0, 1), .init(0.5, 1), .init(1, 1)
                    ],
                    colors: [
                        palette.bg, palette.halo, palette.bg,
                        palette.bg, palette.accentSoft, palette.bg,
                        palette.bg, palette.bg, palette.bg
                    ]
                )
                .opacity(0.25)
            }
            .ignoresSafeArea()
    }
}

enum HaloCardVariant { case standard, hero, inset, plain }

struct HaloCard<Content: View>: View {
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var hero = false
    var variant: HaloCardVariant = .standard
    @ViewBuilder var content: Content
    var body: some View {
        let kind: HaloCardVariant = hero ? .hero : variant
        let shape = RoundedRectangle(
            cornerRadius: kind == .hero ? HaloTokens.Radius.hero : HaloTokens.Radius.card,
            style: .continuous
        )
        content.frame(maxWidth: .infinity, alignment: .leading)
            .padding(kind == .hero ? HaloTokens.Space.hero : kind == .plain ? 0 : HaloTokens.Space.card)
            .background {
                if kind == .plain { Color.clear }
                else if kind == .hero && !reduceTransparency {
                    if #available(iOS 26.0, *) {
                        shape.fill(.ultraThinMaterial).glassEffect(.regular, in: shape)
                    } else {
                        shape.fill(.ultraThinMaterial)
                    }
                } else {
                    shape.fill(kind == .inset ? palette.surfaceSunken : palette.surface)
                }
            }
            .overlay {
                if kind != .plain {
                    shape.stroke(kind == .hero && !reduceTransparency ? palette.glassStroke : palette.hairline, lineWidth: 0.5)
                }
            }
            .shadow(color: palette.shadowTint.opacity(scheme == .dark || kind == .plain ? 0 : 0.08), radius: 24, y: 8)
            .shadow(color: palette.shadowTint.opacity(scheme == .dark || kind == .plain ? 0 : 0.04), radius: 2, y: 1)
    }
}
struct HaloButtonStyle: ButtonStyle {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).frame(minHeight: 54)
            .foregroundStyle(palette.accentOn)
            .background(palette.accent, in: Capsule())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(Motion.resolve(Motion.snappy, reduceMotion: reduceMotion), value: configuration.isPressed)
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
            Capsule().fill(PaletteResolver.eventAccent(event.accentColor)).frame(width: 3, height: 36)
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
                        .background(calendar.isDate(day, inSameDayAs: selected) ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: HaloTokens.Radius.small, style: .continuous))
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
