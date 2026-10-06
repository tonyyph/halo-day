import SwiftUI

/// Event details over the current sky, with the event's arc shown on a small Orbit.
struct DayEventSheet: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.haloReferenceDate) private var referenceDate
    @Environment(\.openURL) private var openURL
    var event: CalendarEvent

    var body: some View {
        let now = referenceDate ?? .now
        let calendar = Calendar.current
        let sky = SkyEngine.state(sky: model.settings.skyID, at: now, coordinate: model.skyCoordinate, calendar: calendar)
        let day = calendar.startOfDay(for: event.startDate)
        let canCountDown = event.startDate > now && event.startDate.timeIntervalSince(now) <= 3600
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.xl) {
                    OrbitCanvas(content: OrbitContent(layout: OrbitLayout(day: day, events: [event], calendar: calendar),
                                                      nowHour: calendar.isDate(now, inSameDayAs: day) ? OrbitGeometry.hours(of: now, calendar: calendar) : nil),
                                sky: sky, style: model.settings.skyID.orbitStyle)
                        .frame(width: 150, height: 150)
                        .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: DS.Space.s) {
                        Text(event.title).font(DS.Typeface.display(30, relativeTo: .title)).fixedSize(horizontal: false, vertical: true)
                        Text(event.startDate.formatted(date: .abbreviated, time: .shortened) + " – " + event.endDate.formatted(date: .omitted, time: .shortened))
                            .font(.headline)
                        if let location = event.location { Label(location, systemImage: "mappin.and.ellipse") }
                        Label(event.calendarName, systemImage: "calendar").opacity(SkyEngine.secondaryOpacity)
                        if event.source == "sample" { Text("Sample event").font(.footnote).opacity(SkyEngine.secondaryOpacity) }
                    }
                    VStack(alignment: .leading, spacing: DS.Space.m) {
                        Button { Task { await model.countDown(event) } } label: {
                            Label("Count down on Lock Screen", systemImage: "timer").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GlassPillStyle(sky: sky))
                        .disabled(!canCountDown)
                        if !canCountDown {
                            Text("Countdowns can start in the hour before an event.").font(.footnote).opacity(SkyEngine.secondaryOpacity)
                        }
                        if event.source != "sample", let url = URL(string: "calshow:\(event.startDate.timeIntervalSinceReferenceDate)") {
                            Button { openURL(url) } label: { Label("Open in Calendar", systemImage: "arrow.up.right").frame(maxWidth: .infinity) }
                                .buttonStyle(GlassPillStyle(sky: sky))
                        }
                    }
                }
                .padding(DS.Space.xl)
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .foregroundStyle(sky.inkColor.color)
        .tint(sky.inkColor.color)
        .environment(\.colorScheme, sky.ink == .light ? .dark : .light)
        .presentationDetents([.medium, .large])
        .presentationBackground { SkyBackground(state: sky) }
    }
}
