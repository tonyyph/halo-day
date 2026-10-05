import SwiftUI
import WidgetKit

struct WidgetGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var message: String?
    @State private var home = false
    @State private var step = 0

    private var steps: [String] {
        home
            ? [
                "Touch and hold an empty spot on your Home Screen.",
                "Tap Edit, then Add Widget.",
                "Search for Halo Day and pick a size.",
                "Tap Add Widget, then Done."
            ]
            : [
                "Touch and hold your Lock Screen, then tap Customize.",
                "Choose Lock Screen, then tap the widget area under the clock.",
                "Find Halo Day and tap the widgets you want.",
                "Tap a widget to choose a preset, then tap Done."
            ]
    }

    var body: some View {
        ZStack {
            ThemeBackground()
            VStack(spacing: 24) {
                SectionTitle(
                    title: "Your Halo, on display",
                    subtitle: "You choose the widgets. iOS takes care of the Lock Screen."
                )

                HaloSegmented(
                    options: [(false, "Lock Screen"), (true, "Home Screen")],
                    selection: $home
                )
                .onChange(of: home) { _, _ in step = 0 }

                TabView(selection: $step) {
                    ForEach(steps.indices, id: \.self) { index in
                        VStack(spacing: 24) {
                            GuideStepIllustration(step: index, home: home, active: step == index)

                            Text(LocalizedStringKey(steps[index]))
                                .haloFont(.displayM)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(24)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HaloPagerIndicator(total: steps.count, selection: step)

                Button("I've added it") { verifyWidgets() }
                    .buttonStyle(HaloButtonStyle())

                Button("Copy setup steps") {
                    UIPasteboard.general.string = steps.enumerated()
                        .map { "\($0.offset + 1). \(String(localized: String.LocalizationValue($0.element)))" }
                        .joined(separator: "\n")
                }
                .frame(minHeight: 44)

                if let message {
                    Text(message)
                        .haloFont(.subhead)
                        .foregroundStyle(palette.ink2)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: 600)
            .padding(20)
        }
        .toolbar { Button("Done") { dismiss() } }
        .presentationDetents([.large])
        .presentationCornerRadius(32)
    }

    private func verifyWidgets() {
        WidgetCenter.shared.getCurrentConfigurations { result in
            Task { @MainActor in
                switch result {
                case .success(let configurations):
                    message = configurations.isEmpty
                        ? String(localized: "We can't see it yet. Widgets sometimes take a moment. Try again.")
                        : String(localized: "Your Halo is live.")
                case .failure:
                    message = String(localized: "We can't see it yet. Widgets sometimes take a moment. Try again.")
                }
            }
        }
    }
}
