import SwiftUI
import WidgetKit

/// How to place Halo widgets: iOS does the placing, so this shows the steps next to what the widget will look like.
struct WidgetGuideView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var home = false
    @State private var message: String?

    private var steps: [String] {
        home
            ? [String(localized: "Touch and hold an empty spot on your Home Screen."),
               String(localized: "Tap Edit, then Add Widget."),
               String(localized: "Search for Halo Day and pick a widget and size."),
               String(localized: "Tap Add Widget, then Done.")]
            : [String(localized: "Touch and hold your Lock Screen, then tap Customize."),
               String(localized: "Choose Lock Screen, then tap the area under the clock."),
               String(localized: "Find Halo Day and tap the widgets from your setup."),
               String(localized: "Touch and hold a widget to pick a setup, then tap Done.")]
    }

    var body: some View {
        SkyScreen { sky, now in
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.xl) {
                    VStack(alignment: .leading, spacing: DS.Space.s) {
                        Text("Your Halo, on display").font(DS.Typeface.display(28, relativeTo: .title))
                        Text("You choose the widgets in Studio. iOS places them for you.").font(.subheadline).opacity(SkyEngine.secondaryOpacity)
                    }
                    Picker("Where", selection: $home) {
                        Text("Lock Screen").tag(false)
                        Text("Home Screen").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("guide-where")
                    preview(sky: sky, now: now)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: DS.Space.m) {
                        ForEach(steps.indices, id: \.self) { index in
                            HStack(alignment: .top, spacing: DS.Space.m) {
                                Text("\(index + 1)").font(DS.Typeface.title(17, relativeTo: .headline))
                                    .frame(width: 32, height: 32)
                                    .haloGlass(Circle(), tint: sky.mid.color)
                                    .accessibilityHidden(true)
                                Text(steps[index]).font(.body).fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, 5)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(Text("Step \(index + 1): \(steps[index])"))
                        }
                    }
                    VStack(spacing: DS.Space.s) {
                        Button { verify() } label: { Text("I've added it").font(.headline).frame(maxWidth: .infinity) }
                            .buttonStyle(GlassPillStyle(sky: sky))
                            .accessibilityIdentifier("guide-verify")
                        Button("Copy steps") {
                            UIPasteboard.general.string = steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
                            message = String(localized: "Steps copied.")
                        }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("guide-copy")
                        if let message {
                            Text(message).font(.subheadline).opacity(SkyEngine.secondaryOpacity).multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(DS.Space.xl)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: home) { _, _ in message = nil }
        }
        .toolbar { Button("Done") { dismiss() } }
    }

    @ViewBuilder
    private func preview(sky: SkyState, now: Date) -> some View {
        let data = WidgetData(date: now, events: model.events(on: now), habits: model.habits, focus: model.focus,
                              countdown: model.countdowns.first, isSample: model.isSample)
        let setup = model.setups.first { $0.id == model.activeSetupID } ?? model.setups.first ?? .starter(name: String(localized: "My Halo"), sky: model.settings.skyID)
        if home {
            let homeSky = SkyEngine.state(sky: setup.skyID, at: now, coordinate: model.skyCoordinate)
            HomeWidgetView(kind: .orbit, family: .small, data: data, sky: homeSky, style: setup.skyID.orbitStyle,
                           coordinate: model.skyCoordinate, locked: false)
                .frame(width: HomeFamily.small.size.width, height: HomeFamily.small.size.height)
                .background(SkyBackground(state: homeSky))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
        } else {
            LockPreview(setup: setup, data: data, now: now, moment: .now, vibrant: false, coordinate: model.skyCoordinate) { _ in }
                .frame(width: 180, height: 180 * LockPreview.screen.height / LockPreview.screen.width)
                .allowsHitTesting(false)
        }
    }

    private func verify() {
        WidgetCenter.shared.getCurrentConfigurations { result in
            Task { @MainActor in
                if case let .success(configurations) = result, !configurations.isEmpty {
                    message = String(localized: "Your Halo is live.")
                } else {
                    message = String(localized: "We can't see it yet. Widgets sometimes take a moment. Try again.")
                }
            }
        }
    }
}
