import SwiftUI

struct EventDetailView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var event: CalendarEvent

    var body: some View {
        HaloScreen {
            Text(event.title).haloFont(.displayM).fixedSize(horizontal: false, vertical: true)
            HaloCard {
                VStack(alignment: .leading, spacing: HaloTokens.Space.card) {
                    Label(event.calendarName, systemImage: "calendar")
                    Text(event.startDate, format: .dateTime.weekday().month().day().hour().minute())
                    Text(event.endDate, format: .dateTime.hour().minute())
                        .foregroundStyle(.secondary)
                    if let location = event.location {
                        Label(location, systemImage: "mappin")
                    }
                    if event.source == "sample" {
                        Text("Sample event").haloFont(.caption)
                    }
                }
            }
            Button("Count down to this") {
                Task { await model.countDown(event) }
            }
            .buttonStyle(HaloButtonStyle())
            Text("Live countdowns can begin in the hour before an event.")
                .haloFont(.caption)
                .foregroundStyle(.secondary)
        }
        .toolbar { Button("Done") { dismiss() } }
    }
}
