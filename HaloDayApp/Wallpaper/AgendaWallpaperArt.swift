import SwiftUI

/// A Lock Screen wallpaper with the agenda drawn into it, laid out at true iPhone points (393 × 852).
/// The top third stays clear for iOS's date and clock, the bottom for the flashlight and camera buttons.
struct AgendaWallpaperArt: View {
    static let size = CGSize(width: 393, height: 852)

    var agenda: AgendaWallpaper
    var data: AgendaData
    var sky: SkyState
    var style: OrbitStyle
    var orbit: OrbitContent
    var photo: UIImage?

    private var usesPhoto: Bool { agenda.usesPhoto && photo != nil }
    /// Below the clock, or below a widget row when the person keeps one.
    private var top: CGFloat { agenda.roomForWidgets ? 360 : 270 }
    private var ink: Color {
        usesPhoto ? (agenda.photoIsDark ? SkyEngine.lightInk.color : SkyEngine.darkInk.color) : sky.inkColor.color
    }
    private var inkIsLight: Bool { usesPhoto ? agenda.photoIsDark : sky.ink == .light }
    private var accent: Color { SkyColor(hexString: agenda.accentHex)?.color ?? .red }

    var body: some View {
        ZStack(alignment: .top) {
            background
            // Frosted glass, baked in: a photo blurred, shown only through the cards' shapes.
            // A sky is already a soft gradient, so its cards are a tint alone.
            if usesPhoto {
                background
                    .blur(radius: 28, opaque: true)
                    .mask { content.environment(\.agendaGlassShapes, true) }
            }
            content.environment(\.agendaGlassTint, inkIsLight ? 0.8 : 0.4)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var background: some View {
        if usesPhoto, let photo {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: Self.size.width, height: Self.size.height)
                .clipped()
        } else {
            SkyBackground(state: sky)
        }
    }

    @ViewBuilder
    private var content: some View {
        Group {
            switch agenda.layout {
            case .week: weekLayout
            case .month: monthLayout
            case .orbit: orbitLayout
            }
        }
        .padding(.top, top)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .top)
        .environment(\.colorScheme, inkIsLight ? .dark : .light)
    }

    // MARK: Week — seven columns of colour chips, then what's left today

    private var weekLayout: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 4) {
                ForEach(data.week) { day in weekColumn(day) }
            }
            .padding(.horizontal, 10)
            upcomingList(limit: agenda.roomForWidgets ? 2 : 3)
                .padding(.horizontal, 22)
        }
    }

    private func weekColumn(_ day: AgendaDay) -> some View {
        VStack(spacing: 4) {
            VStack(spacing: 0) {
                Text(day.weekday).font(.system(size: 11, weight: .medium)).opacity(0.85)
                Text(verbatim: "\(day.dayNumber)").font(.system(size: 18, weight: .semibold))
            }
            .foregroundStyle(ink)
            .frame(height: 40)
            ForEach(Array(day.items.enumerated()), id: \.offset) { index, event in
                chip(event, more: index == day.items.count - 1 ? day.more : 0)
            }
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 4)
        // Every column the same fixed height, so the highlight on today never stretches.
        .frame(maxWidth: .infinity)
        .frame(height: 40 + 4 * 42 + 8, alignment: .top)
        .agendaGlass(radius: 10, active: day.isToday, tint: inkIsLight ? 0.2 : 0.45)
    }

    private func chip(_ event: CalendarEvent, more: Int) -> some View {
        let base = SkyColor(hexString: event.accentColor) ?? SkyColor(hex: 0xC9D3EE)
        return VStack(alignment: .leading, spacing: 1) {
            Text(event.isAllDay ? String(localized: "All day") : event.startDate.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 8, weight: .medium)).opacity(0.75)
            Text(event.title).font(.system(size: 11, weight: .semibold))
        }
        .lineLimit(1)
        .foregroundStyle(SkyEngine.darkInk.color)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, minHeight: 38, maxHeight: 38, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(base.mixed(with: SkyColor(hex: 0xFFFFFF), 0.5).color))
        .overlay(alignment: .topTrailing) {
            if more > 0 {
                Text(verbatim: "+\(more)").font(.system(size: 7, weight: .bold))
                    .padding(.horizontal, 3).padding(.vertical, 1)
                    .background(Capsule().fill(SkyEngine.darkInk.color.opacity(0.18)))
                    .foregroundStyle(SkyEngine.darkInk.color)
                    .padding(3)
            }
        }
    }

    // MARK: Month — progress card, then the month as a grid beside today's events

    private var monthLayout: some View {
        VStack(spacing: 14) {
            VStack(spacing: 9) {
                HStack {
                    Text(data.monthTitle)
                    Spacer()
                    Text(data.monthFraction, format: .percent.precision(.fractionLength(0)))
                }
                .font(.system(size: 17, weight: .semibold))
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(accent.opacity(0.2))
                        Capsule().fill(accent).frame(width: max(4, proxy.size.width * data.monthFraction))
                    }
                }
                .frame(height: 4)
                HStack {
                    Text("\(data.dayOfMonth) of \(data.daysInMonth) days")
                    Spacer()
                    Text(DaysLeft.string(data.daysLeft))
                }
                .font(.system(size: 13, weight: .semibold))
                .opacity(0.85)
            }
            .foregroundStyle(accent)
            .padding(16)
            .agendaGlass(radius: 20)

            HStack(alignment: .top, spacing: 16) {
                monthGrid
                VStack(alignment: .leading, spacing: 14) {
                    if data.upcoming.isEmpty {
                        Text("Nothing else today").font(.system(size: 15, weight: .semibold))
                    }
                    ForEach(data.upcoming.prefix(3)) { event in
                        HStack(alignment: .top, spacing: 8) {
                            RoundedRectangle(cornerRadius: 1.5).fill(accent).frame(width: 3, height: 38)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(event.title).font(.system(size: 15, weight: .bold)).lineLimit(1)
                                Text(range(event)).font(.system(size: 12, weight: .semibold)).opacity(0.85).lineLimit(1)
                            }
                        }
                    }
                }
                .padding(.top, 26)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(accent)
            .padding(16)
            .agendaGlass(radius: 20)
        }
        .padding(.horizontal, 14)
    }

    private var monthGrid: some View {
        let cell: CGFloat = 22
        return VStack(alignment: .leading, spacing: 6) {
            Text(data.monthShort).font(.system(size: 17, weight: .semibold)).padding(.leading, 20)
            HStack(alignment: .top, spacing: 5) {
                VStack(spacing: 5) {
                    ForEach(Array(data.weekdayInitials.enumerated()), id: \.offset) { _, initial in
                        Text(initial).font(.system(size: 9, weight: .semibold)).frame(width: 14, height: cell)
                    }
                }
                ForEach(Array(data.monthColumns.enumerated()), id: \.offset) { _, column in
                    VStack(spacing: 5) {
                        ForEach(Array(column.enumerated()), id: \.offset) { _, day in monthCell(day, size: cell) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func monthCell(_ day: AgendaMonthCell, size: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        switch day.state {
        case .outside: Color.clear.frame(width: size, height: size)
        case .past: shape.fill(accent).frame(width: size, height: size)
        case .today:
            shape.fill(accent).frame(width: size, height: size)
                .overlay(shape.inset(by: 2).strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5))
        case .future: shape.fill(day.hasEvents ? accent.opacity(0.45) : Color.white.opacity(0.4)).frame(width: size, height: size)
        }
    }

    // MARK: Orbit — the day as Halo draws it, then what's left today

    private var orbitLayout: some View {
        VStack(spacing: 22) {
            OrbitCanvas(content: orbit, sky: sky, style: style)
                .frame(width: agenda.roomForWidgets ? 200 : 250, height: agenda.roomForWidgets ? 200 : 250)
            upcomingList(limit: agenda.roomForWidgets ? 2 : 3)
                .padding(.horizontal, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Shared

    private func upcomingList(limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if data.upcoming.isEmpty {
                Text("Nothing else today").font(.system(size: 19, weight: .semibold))
            }
            ForEach(data.upcoming.prefix(limit)) { event in
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(SkyColor(hexString: event.accentColor)?.color ?? accent)
                        .frame(width: 3, height: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title).font(.system(size: 19, weight: .semibold)).lineLimit(1)
                        Label(range(event), systemImage: "clock").font(.system(size: 14, weight: .medium)).opacity(0.85)
                    }
                }
            }
            if data.isSample {
                Text("Sample day").font(.system(size: 12, weight: .medium)).opacity(0.7)
            }
        }
        .foregroundStyle(ink)
        .shadow(color: (inkIsLight ? Color.black : Color.white).opacity(0.25), radius: 3)
    }

    private func range(_ event: CalendarEvent) -> String {
        "\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened))"
    }
}

// MARK: Baked glass

private struct AgendaGlassShapesKey: EnvironmentKey { static let defaultValue = false }
private struct AgendaGlassTintKey: EnvironmentKey { static let defaultValue = 0.4 }
extension EnvironmentValues {
    /// True while drawing the mask that lets the blurred background through the cards.
    var agendaGlassShapes: Bool {
        get { self[AgendaGlassShapesKey.self] }
        set { self[AgendaGlassShapesKey.self] = newValue }
    }
    /// How white the glass is: brighter over dark backgrounds so the accent text on it stays readable.
    var agendaGlassTint: Double {
        get { self[AgendaGlassTintKey.self] }
        set { self[AgendaGlassTintKey.self] = newValue }
    }
}

private struct AgendaGlass: ViewModifier {
    @Environment(\.agendaGlassShapes) private var shapes
    @Environment(\.agendaGlassTint) private var tint
    var radius: CGFloat
    var active: Bool
    /// Overrides the default tint, for glass that carries ink-coloured text rather than accent text.
    var tintOverride: Double?

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if !active {
            content
        } else if shapes {
            content.background(shape.fill(Color.black))
        } else {
            content
                .background(shape.fill(Color.white.opacity(tintOverride ?? tint)))
                .overlay(shape.strokeBorder(Color.white.opacity(0.5), lineWidth: 0.8))
        }
    }
}

private extension View {
    func agendaGlass(radius: CGFloat, active: Bool = true, tint: Double? = nil) -> some View {
        modifier(AgendaGlass(radius: radius, active: active, tintOverride: tint))
    }
}
