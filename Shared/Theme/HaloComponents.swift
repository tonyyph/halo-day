import SwiftUI

struct ThemeBackground: View {
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion
    @State private var visible = false
    var breathing = false

    var body: some View {
        palette.bg
            .overlay {
                if breathing && !reduceMotion {
                    TimelineView(.animation(minimumInterval: 1 / 30, paused: !visible)) { context in
                        let phase = context.date.timeIntervalSinceReferenceDate / 8 * 2 * .pi
                        mesh(drift: Float(sin(phase)) * 0.02)
                    }
                } else { mesh(drift: 0) }
            }
            .ignoresSafeArea()
            .onAppear { visible = true }
            .onDisappear { visible = false }
    }

    private func mesh(drift: Float) -> some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                .init(0, 0), .init(0.5, 0), .init(1, 0),
                .init(0, 0.5), .init(0.5 + drift, 0.5 + drift), .init(1, 0.5),
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
}

enum HaloCardVariant { case standard, hero, inset, plain }

struct HaloCard<Content: View>: View {
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var scheme
    @Environment(\.haloReduceTransparency) private var reduceTransparency
    @Environment(\.haloReduceMotion) private var reduceMotion
    var hero = false
    var variant: HaloCardVariant = .standard
    @ViewBuilder var content: Content
    var body: some View {
        let noMotion = reduceMotion
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
                        shape.fill(palette.surface.opacity(0.1)).glassEffect(.regular, in: shape)
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
            .scrollTransition(.interactive) { view, phase in
                view
                    .opacity(phase.isIdentity ? 1 : 0.6)
                    .scaleEffect(noMotion || phase.isIdentity ? 1 : 0.96)
            }
    }
}
struct HaloButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HaloActionStyle().makeBody(configuration: configuration)
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
    @Environment(\.haloReduceMotion) private var reduceMotion
    @State private var appeared = false
    var icon = "sun.horizon"
    var title: String
    var message: String
    var body: some View {
        VStack(spacing: HaloTokens.Space.row) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, options: .nonRepeating, value: reduceMotion ? false : appeared)
            Text(LocalizedStringKey(title)).font(HaloTokens.title)
            Text(LocalizedStringKey(message)).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(HaloTokens.Space.major)
            .onAppear { appeared = true }
    }
}
struct AgendaRow: View {
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicType
    var event: CalendarEvent
    var date: Date = .now
    var body: some View {
        HStack(alignment: .top, spacing: HaloTokens.Space.row) {
            Group {
                if event.isAllDay { Text("All day") } else { Text(event.startDate, style: .time) }
            }.font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 65, alignment: .leading)
            Rectangle().fill(palette.hairline).frame(width: 1, height: 64)
                .overlay(alignment: .top) {
                    Circle().fill(PaletteResolver.eventAccent(event.accentColor)).frame(width: 7, height: 7).offset(y: 7)
                }
                .frame(width: 9, height: 40)
            VStack(alignment: .leading, spacing: HaloTokens.Space.tiny) {
                Text(event.title).font(.headline).lineLimit(dynamicType.isAccessibilitySize ? nil : 1)
                Text(event.location ?? event.calendarName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if event.endDate < date { Image(systemName: "checkmark").foregroundStyle(.secondary) }
            else if event.startDate <= date { Text("NOW").font(.caption2.bold()).foregroundStyle(.tint) }
        }.padding(.vertical, HaloTokens.Space.small)
            .opacity(event.endDate < date ? 0.6 : 1)
    }
}
struct MiniMonthGrid: View {
    var month: Date
    var highlights: Set<Int> = []
    var selection: ((Date) -> Void)?
    @Namespace private var selectedDay
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.haloReduceMotion) private var reduceMotion
    var body: some View {
        let calendar = Calendar.current
        let first = calendar.dateInterval(of: .month, for: month)!.start
        let count = calendar.range(of: .day, in: .month, for: month)!.count
        let offset = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let weekStart = calendar.date(byAdding: .day, value: -offset, to: first)!
        VStack(spacing: selection == nil ? 2 : 6) {
            if selection != nil {
                HStack(spacing: 2) {
                    ForEach(0..<7, id: \.self) { weekdayIndex in
                        let weekday = calendar.date(byAdding: .day, value: weekdayIndex, to: weekStart)!
                        Text(weekday, format: .dateTime.weekday(.narrow))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 24)
                    }
                }
                .accessibilityHidden(true)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: selection == nil ? 2 : 6) {
                ForEach(0..<(count + offset), id: \.self) { index in
                    if index < offset { Color.clear.frame(height: selection == nil ? 18 : 44) }
                    else {
                        let number = index - offset + 1
                        let day = calendar.date(byAdding: .day, value: number - 1, to: first)!
                        if let selection {
                            Button { selection(day) } label: {
                                dayCell(number, day: day)
                                    .frame(minHeight: dynamicType.isAccessibilitySize ? 52 : 44)
                            }
                            .buttonStyle(PressableStyle())
                        } else { dayCell(number, day: day) }
                    }
                }
            }
        }
    }
    private func dayCell(_ number: Int, day: Date) -> some View {
        let compact = selection == nil
        let selected = !compact && Calendar.current.isDate(day, inSameDayAs: month)
        let diameter: CGFloat = compact ? 18 : dynamicType.isAccessibilitySize ? 38 : 28
        return VStack(spacing: compact ? 0 : 2) {
            Text(number, format: .number)
                .font((compact ? Font.caption2 : dynamicType.isAccessibilitySize ? Font.body : Font.caption).monospacedDigit())
                .frame(width: diameter, height: diameter)
                .background {
                    if selected {
                        Circle()
                            .fill(Color.accentColor.opacity(0.16))
                            .matchedGeometryEffect(
                                id: "selected-day", in: selectedDay,
                                properties: reduceMotion ? [] : .frame
                            )
                    }
                }
            Circle()
                .fill(highlights.contains(number) ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear))
                .frame(width: compact ? 2 : 4, height: compact ? 2 : 4)
        }
        .frame(maxWidth: .infinity)
            .foregroundStyle(Calendar.current.isDateInToday(day) ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            .accessibilityLabel(Text(day, format: .dateTime.month().day()))
    }
}
