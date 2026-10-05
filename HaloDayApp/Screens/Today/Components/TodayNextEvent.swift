import SwiftUI

struct TodayNextEvent: View {
    private let next: CalendarEvent?
    private let tomorrow: CalendarEvent?
    private let tomorrowTime: String
    private let hasEvents: Bool
    var date: Date
    var fixedDate: Bool
    var onOpen: (CalendarEvent) -> Void
    var onCountdown: (CalendarEvent) -> Void
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion

    init(events: [CalendarEvent], tomorrow: [CalendarEvent], date: Date, fixedDate: Bool, onOpen: @escaping (CalendarEvent) -> Void, onCountdown: @escaping (CalendarEvent) -> Void) {
        next = events.first { !$0.isAllDay && $0.endDate > date }
        self.tomorrow = tomorrow.first { !$0.isAllDay }
        tomorrowTime = self.tomorrow?.startDate.formatted(.dateTime.hour().minute()) ?? ""
        hasEvents = !events.isEmpty
        self.date = date; self.fixedDate = fixedDate; self.onOpen = onOpen; self.onCountdown = onCountdown
    }

    var body: some View {
        if let next {
            HaloCard(hero: true) {
                HStack(alignment: .top, spacing: 16) {
                    Capsule().fill(PaletteResolver.eventAccent(next.accentColor)).frame(width: 3)
                    VStack(alignment: .leading, spacing: 12) {
                        Button { onOpen(next) } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 6) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 6))
                                        .symbolEffect(.pulse, options: .nonRepeating, value: reduceMotion ? false : next.startDate <= date)
                                    Text(next.startDate <= date ? "NOW" : "NEXT").captionUpper()
                                    Spacer()
                                    relative(next)
                                }
                                .foregroundStyle(palette.accentInk)
                                Text(next.title).haloFont(.displayM).fixedSize(horizontal: false, vertical: true)
                                HStack(spacing: 5) {
                                    Text(next.startDate, style: .time); Text("–"); Text(next.endDate, style: .time)
                                }
                                .haloFont(.subhead).monospacedDigit()
                                Label(next.location ?? next.calendarName, systemImage: next.location == nil ? "calendar" : "mappin")
                                    .haloFont(.footnote).foregroundStyle(palette.ink2).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(PressableStyle())
                        .haloZoomSource("today-next-\(next.id)")
                        HaloButton(title: "Count down", kind: .glass) { onCountdown(next) }
                    }
                }
            }
        } else {
            HaloCard(variant: .inset) {
                VStack(spacing: 12) {
                    EmptyState(icon: hasEvents ? "moon.stars" : "sun.horizon",
                               title: hasEvents ? "That's a wrap for today." : "An open day",
                               message: "Nothing on the calendar. Make room for something good.")
                    if let tomorrow {
                        Text("Tomorrow starts with \(tomorrow.title) at \(tomorrowTime).")
                            .haloFont(.footnote).foregroundStyle(palette.ink2)
                    }
                }
            }
        }
    }

    @ViewBuilder private func relative(_ event: CalendarEvent) -> some View {
        let ongoing = event.startDate <= date
        let target = ongoing ? event.endDate : event.startDate
        if fixedDate {
            let minutes = max(0, Int(target.timeIntervalSince(date) / 60))
            Text(ongoing ? String(localized: "ends in \(minutes) min") : String(localized: "in \(minutes) min"))
                .haloFont(.footnote)
        } else {
            HStack(spacing: 3) {
                Text(ongoing ? String(localized: "Ends in") : String(localized: "in"))
                Text(target, style: .relative)
            }
            .haloFont(.footnote)
        }
    }
}

#Preview("Next event · Ruby") {
    DesignPreview(themeID: "rubyGlass", scheme: .dark) {
        TodayNextEvent(events: MockData.events(), tomorrow: MockData.events(), date: .now, fixedDate: false,
                       onOpen: { _ in }, onCountdown: { _ in })
    }
}

#Preview("Next event · Empty AX3") {
    DesignPreview(accessibility: true, reduceMotion: true) {
        TodayNextEvent(events: [], tomorrow: [], date: .now, fixedDate: true, onOpen: { _ in }, onCountdown: { _ in })
    }
}
