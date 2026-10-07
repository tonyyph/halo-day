import SwiftUI

/// How to keep an agenda wallpaper current: iOS lets only Shortcuts set the wallpaper, so an automation does it.
struct AgendaAutomationGuide: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let steps: [String] = [
        String(localized: "Open Shortcuts, tap Automation, then the + button."),
        String(localized: "Choose Time of Day (for example every morning), or App → Calendar → Is Closed to refresh after you edit events."),
        String(localized: "Set it to Run Immediately."),
        String(localized: "Add the action Make Halo Wallpaper."),
        String(localized: "Add Set Wallpaper Photo, choose Lock Screen, and turn off Show Preview and Crop to Subject."),
    ]

    var body: some View {
        NavigationStack {
            SkyScreen { sky, _ in
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Space.xl) {
                        VStack(alignment: .leading, spacing: DS.Space.s) {
                            Text("Keep it up to date").font(DS.Typeface.display(28, relativeTo: .title))
                            Text("The agenda is part of the wallpaper picture, so it changes when the wallpaper is set again. A Shortcuts automation can do that for you, as often as you like.")
                                .font(.subheadline).opacity(SkyEngine.secondaryOpacity)
                        }
                        VStack(alignment: .leading, spacing: DS.Space.m) {
                            ForEach(steps.indices, id: \.self) { index in
                                HStack(alignment: .top, spacing: DS.Space.m) {
                                    Text("\(index + 1)").font(DS.Typeface.title(17, relativeTo: .headline))
                                        .frame(width: 32, height: 32)
                                        .haloGlass(Circle(), tint: sky.mid.color)
                                        .accessibilityHidden(true)
                                    Text(steps[index]).font(.body).fixedSize(horizontal: false, vertical: true).padding(.top, 5)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                        Button {
                            if let url = URL(string: "shortcuts://") { openURL(url) }
                        } label: { Label("Open Shortcuts", systemImage: "square.2.layers.3d").font(.headline).frame(maxWidth: .infinity) }
                        .buttonStyle(GlassPillStyle(sky: sky))
                        .accessibilityIdentifier("agenda-open-shortcuts")
                        Text("Tip: on the Lock Screen, remove the widgets under the clock (or turn on Leave room for widgets) so they don't cover the agenda.")
                            .font(.footnote).opacity(SkyEngine.secondaryOpacity)
                    }
                    .padding(DS.Space.xl)
                }
            }
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
