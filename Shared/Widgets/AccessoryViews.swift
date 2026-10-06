import SwiftUI

/// One Lock Screen accessory, drawn identically in Studio and in WidgetKit.
/// `tint == nil` is the vibrant rendering iOS uses on the Lock Screen (a single ink); a colour gives the design view.
struct AccessoryView: View {
    var kind: WidgetKind
    var family: AccessoryFamily
    var data: WidgetData
    var tint: Color?

    var body: some View {
        content
            .foregroundStyle(tint ?? Color.primary)
            .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var content: some View {
        switch (kind, family) {
        case (.orbit, _): AccessoryOrbit(data: data)
        case (.nextUp, .inline): Text(nextInline)
        case (.nextUp, _): nextRectangle
        case (.rhythm, _): rhythmRectangle
        case (.rituals, _): AccessoryRitualRing(done: data.ritualsDone, total: data.habits.count)
        case (.countdown, .circular): countdownRing
        case (.countdown, _): countdownRectangle
        case (.month, .inline): Text(monthInline)
        case (.month, _): monthRectangle
        }
    }

    private func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }

    private var nextInline: String {
        guard let event = data.nextEvent else { return String(localized: "A clear day.") }
        return "\(event.title) · \(time(event.startDate))"
    }

    private var nextRectangle: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let event = data.nextEvent {
                Text(badge(for: event)).font(.caption2.weight(.semibold)).opacity(0.8)
                Text(event.title).font(DS.Typeface.title(15, relativeTo: .headline)).lineLimit(1)
                Text("\(time(event.startDate)) – \(time(event.endDate))").font(.caption2).opacity(0.8)
            } else {
                Text("A clear day.").font(DS.Typeface.title(15, relativeTo: .headline))
                Text("Nothing else today").font(.caption2).opacity(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func badge(for event: CalendarEvent) -> String {
        if event.startDate <= data.date { return String(localized: "Now") }
        let minutes = Int(event.startDate.timeIntervalSince(data.date) / 60)
        return minutes < 90 ? String(localized: "In \(max(1, minutes)) min") : time(event.startDate)
    }

    private var rhythmRectangle: some View {
        VStack(alignment: .leading, spacing: 2) {
            let rows = data.upcoming(limit: 3)
            if rows.isEmpty {
                Text("A clear day.").font(DS.Typeface.title(15, relativeTo: .headline))
            }
            ForEach(rows) { event in
                HStack(spacing: 6) {
                    Text(time(event.startDate)).font(.caption2.monospacedDigit()).opacity(0.8)
                    Text(event.title).font(.caption.weight(.medium)).lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var countdownRing: some View {
        let days = data.countdownDays ?? 0
        return ZStack {
            Circle().stroke(.primary.opacity(0.25), lineWidth: 3)
            Circle().trim(from: 0, to: max(0.04, 1 - min(Double(days), 60) / 60))
                .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if data.countdown == nil {
                Image(systemName: "hourglass").font(.title3)
            } else {
                Text(verbatim: "\(days)").font(.title3.weight(.semibold).monospacedDigit()).minimumScaleFactor(0.5)
            }
        }
        .padding(3)
    }

    private var countdownRectangle: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let countdown = data.countdown, let days = data.countdownDays {
                Text(countdown.title).font(DS.Typeface.title(15, relativeTo: .headline)).lineLimit(1)
                Text("\(days) days left").font(.caption.weight(.medium))
                Text(countdown.targetDate, format: .dateTime.day().month(.abbreviated)).font(.caption2).opacity(0.8)
            } else {
                Text("Add a countdown").font(DS.Typeface.title(15, relativeTo: .headline))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var monthInline: String {
        let month = data.monthProgress
        let name = data.date.formatted(.dateTime.month(.abbreviated))
        let percent = month.fraction.formatted(.percent.precision(.fractionLength(0)))
        return "\(name) · \(percent) · " + String(localized: "\(month.daysLeft) days left")
    }

    private var monthRectangle: some View {
        let month = data.monthProgress
        return VStack(alignment: .leading, spacing: 3) {
            Text(data.date, format: .dateTime.month(.wide)).font(DS.Typeface.title(15, relativeTo: .headline))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.primary.opacity(0.25))
                    Capsule().frame(width: max(4, proxy.size.width * month.fraction))
                }
            }
            .frame(height: 5)
            Text("Day \(month.day) of \(month.daysInMonth)").font(.caption2).opacity(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The day as a small ring: today's events as arcs and a dot at now.
struct AccessoryOrbit: View {
    var data: WidgetData

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = side * 0.4
            let width = side * 0.09
            let orbit = data.orbit
            var faint = context
            faint.opacity = 0.25
            faint.stroke(OrbitPath.arc(center: center, radius: radius, from: 0, to: 24), with: .foreground, lineWidth: width)
            for arc in orbit.layout.arcs {
                context.stroke(OrbitPath.arc(center: center, radius: radius, from: arc.start, to: arc.end), with: .foreground,
                               style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
            if let now = orbit.nowHour {
                let point = OrbitGeometry.point(forHour: now, radius: radius, center: center)
                let dot = side * 0.085
                context.fill(Path(ellipseIn: CGRect(x: point.x - dot, y: point.y - dot, width: dot * 2, height: dot * 2)), with: .foreground)
            }
        }
        .accessibilityLabel(Text("Your day"))
    }
}

/// Rituals as a ring of segments; kept ones are solid.
struct AccessoryRitualRing: View {
    var done: Int
    var total: Int

    var body: some View {
        ZStack {
            Canvas { context, size in
                let side = min(size.width, size.height)
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = side * 0.4
                let count = max(1, total)
                let gap = count > 1 ? 0.5 : 0
                for index in 0..<count {
                    let span = 24.0 / Double(count)
                    let start = 12 + Double(index) * span + gap / 2
                    var segment = context
                    segment.opacity = index < done ? 1 : 0.25
                    segment.stroke(OrbitPath.arc(center: center, radius: radius, from: start, to: start + span - gap), with: .foreground,
                                   style: StrokeStyle(lineWidth: side * 0.09, lineCap: .round))
                }
            }
            Text(verbatim: "\(done)/\(total)").font(.caption.weight(.semibold).monospacedDigit())
        }
        .accessibilityLabel(Text("\(done) of \(total) rituals"))
    }
}
