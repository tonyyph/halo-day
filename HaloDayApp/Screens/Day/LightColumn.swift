import SwiftUI

/// The day as a vertical line of light: past rows quiet, "now" glowing, the next event in glass.
struct LightColumn: View {
    var scene: DayScene
    var sky: SkyState
    var now: Date
    var focus: FocusSession?
    var onEvent: (CalendarEvent) -> Void
    var onFocus: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.l) {
            if !scene.hasTimedEvents { empty }
            ForEach(scene.column) { item in
                switch item.kind {
                case let .event(event, phase): eventRow(event, phase: phase)
                case let .now(free): nowRow(free)
                case let .gap(minutes): gapRow(minutes)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .leading) {
            LinearGradient(colors: [sky.inkColor.color.opacity(0.22), sky.inkColor.color.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(width: 1.5)
                .padding(.leading, 10)
                .accessibilityHidden(true)
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            Text("A clear day.").font(DS.Typeface.display(28, relativeTo: .title))
            if scene.isToday {
                Button("Start a focus session", action: onFocus).buttonStyle(GlassPillStyle(sky: sky))
            }
        }
        .padding(.leading, 36)
    }

    private func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }

    @ViewBuilder
    private func eventRow(_ event: CalendarEvent, phase: DayColumnItem.Phase) -> some View {
        let color = (SkyColor(hexString: event.accentColor) ?? sky.glow).color
        Button { onEvent(event) } label: {
            HStack(alignment: .top, spacing: 14) {
                Circle()
                    .strokeBorder(color, lineWidth: 2)
                    .background(Circle().fill(phase == .past ? Color.clear : color))
                    .frame(width: 10, height: 10)
                    .padding(.top, 6)
                    .frame(width: 22)
                switch phase {
                case .current, .next:
                    VStack(alignment: .leading, spacing: DS.Space.xs) {
                        Text(badge(event, phase: phase)).font(.caption.weight(.semibold))
                        Text(event.title).font(DS.Typeface.title(20)).multilineTextAlignment(.leading)
                        Text([time(event.startDate) + " – " + time(event.endDate), event.location].compactMap { $0 }.joined(separator: " · "))
                            .font(.footnote)
                            .opacity(SkyEngine.secondaryOpacity)
                    }
                    .padding(DS.Space.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .haloGlass(RoundedRectangle(cornerRadius: DS.Radius.glass, style: .continuous), tint: sky.mid.color)
                case .past, .later:
                    VStack(alignment: .leading, spacing: 2) {
                        Text(time(event.startDate)).font(.caption).opacity(SkyEngine.secondaryOpacity)
                        Text(event.title).font(.body).multilineTextAlignment(.leading)
                    }
                    .opacity(phase == .past ? SkyEngine.secondaryOpacity : 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("column-\(event.id)")
    }

    private func badge(_ event: CalendarEvent, phase: DayColumnItem.Phase) -> String {
        if phase == .current { return String(localized: "Happening now · until \(time(event.endDate))") }
        let minutes = Int(event.startDate.timeIntervalSince(now) / 60)
        return minutes < 90 ? String(localized: "In \(max(1, minutes)) min") : time(event.startDate)
    }

    private func nowRow(_ free: Int?) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Circle().fill(.white)
                .frame(width: 14, height: 14)
                .shadow(color: sky.glow.color, radius: 8)
                .shadow(color: sky.glow.color.opacity(0.6), radius: 18)
                .frame(width: 22)
                .accessibilityHidden(true)
            if let focus, focus.isActive {
                Button(action: onFocus) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Focusing").font(.caption.weight(.semibold))
                        Text("Back to your session").font(.body)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("column-focus")
            } else if let free, free >= DaySceneBuilder.minimumGapMinutes {
                Button(action: onFocus) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Now · \(free)′ free").font(.caption.weight(.semibold))
                        Text("Start a focus session").font(.body)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("column-focus")
            } else {
                Text("Now").font(.caption.weight(.semibold))
            }
        }
    }

    private func gapRow(_ minutes: Int) -> some View {
        Text("\(minutes)′ free")
            .font(.footnote)
            .opacity(SkyEngine.secondaryOpacity)
            .padding(.leading, 36)
    }
}
