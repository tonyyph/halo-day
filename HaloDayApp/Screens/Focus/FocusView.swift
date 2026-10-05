import SwiftUI

struct FocusView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion
    @State private var minutes = 50
    @State private var title = ""

    var body: some View {
        HaloScreen {
            SectionTitle(title: "Make space to focus", subtitle: "One thing. Your full attention.")

            FocusDial(minutes: $minutes)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .haloZoomSource("focus-session")

            ChipGroup(
                options: [(25, "25 min"), (50, "50 min"), (90, "90 min")],
                selection: $minutes
            )

            HaloCard(variant: .inset) {
                TextField("Deep work", text: $title)
                    .haloFont(.body)
                    .textInputAutocapitalization(.sentences)
            }

            Button("Begin focus") {
                Task { await model.startFocus(title: title, minutes: minutes) }
            }
            .buttonStyle(HaloButtonStyle())

            islandPreview

            if !model.focusHistory.isEmpty {
                history
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { model.focus?.isActive == true },
            set: { _ in }
        )) {
            if let session = model.focus, session.isActive {
                FocusActiveView(session: session).haloZoomDestination("focus-session")
            }
        }
    }

    private var islandPreview: some View {
        HaloCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("On your Dynamic Island").haloFont(.headline)
                    Spacer()
                    if !model.purchases.isPremium { PremiumChip() }
                }
                HStack(spacing: 12) {
                    Image(systemName: "timer")
                        .foregroundStyle(PaletteResolver.resolve(model.theme, scheme: .dark).accent)
                    Text(model.focus?.isActive == true
                         ? model.focus!.title : String(localized: "Deep work"))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(model.focus?.isActive == true
                         ? Duration.seconds(model.focus!.remaining()).formatted(.time(pattern: .minuteSecond))
                         : "50:00")
                        .monospacedDigit()
                }
                .haloFont(.caption)
                .foregroundStyle(PaletteResolver.resolve(model.theme, scheme: .dark).ink)
                .padding(16)
                .background(
                    PaletteResolver.resolve(ThemeRegistry.theme("graphiteFocus"), scheme: .dark).bg,
                    in: Capsule()
                )

                Text("Live Activities show your timer on the Lock Screen. Dynamic Island appears on supported iPhones.")
                    .haloFont(.footnote)
                    .foregroundStyle(palette.ink2)

                if !model.purchases.isPremium {
                    Button("Unlock Live Activities") { model.showPaywall = true }
                } else if !model.activities.enabled {
                    Text("Live Activities are turned off for Halo Day in iOS Settings.")
                        .haloFont(.footnote)
                }
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time well spent").haloFont(.displayM)
            HaloCard {
                VStack(spacing: 0) {
                    ForEach(model.focusHistory.prefix(7)) { session in
                        HStack {
                            Text(session.title)
                            Spacer()
                            Text(session.startDate, format: .dateTime.month().day())
                            Text("\(session.durationMinutes) min")
                                .foregroundStyle(palette.ink2)
                        }
                        .haloFont(.footnote)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }
}

#Preview { FocusView().environment(HaloModel()) }
