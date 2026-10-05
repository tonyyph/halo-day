import SwiftUI

struct FocusView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.haloNavigation) private var navigation
    @Environment(\.haloReferenceDate) private var referenceDate
    @Environment(\.haloReduceTransparency) private var reduceTransparency
    @State private var minutes = 50
    @State private var title = ""
    @State private var suggestions: [(String, String)] = []
    @State private var activeCover = false
    @State private var lastActive: FocusSession?
    @State private var completed: FocusSession?

    var body: some View {
        HaloScreen {
            SectionTitle(title: "Make space to focus", subtitle: "One thing. Your full attention.")
            FocusDial(minutes: $minutes)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .haloZoomSource("focus-session")
            ChipGroup(options: [(25, "25 min"), (50, "50 min"), (90, "90 min")], selection: $minutes)

            VStack(alignment: .leading, spacing: 12) {
                Text("What are you focusing on?").captionUpper().foregroundStyle(palette.ink2)
                TextField("Deep work", text: $title)
                    .haloFont(.displayS)
                    .textFieldStyle(.plain)
                    .frame(minHeight: 44)
                if !suggestions.isEmpty { ChipGroup(options: suggestions, selection: $title) }
            }

            Toggle("Show on Lock Screen & Dynamic Island", isOn: Binding(
                get: { model.purchases.isPremium && model.settings.liveActivities },
                set: { enabled in
                    if model.purchases.isPremium {
                        model.settings.liveActivities = enabled
                        model.persist()
                    } else { model.showPaywall = true }
                }
            ))
            .haloFont(.subhead)
            .tint(palette.accent)

            FocusIslandPreview(
                session: model.focus?.isActive == true ? model.focus : nil,
                minutes: minutes, theme: model.theme, premium: model.purchases.isPremium
            ) { model.showPaywall = true }

            if model.purchases.isPremium && !model.activities.enabled {
                Text("Live Activities are turned off for Halo Day in iOS Settings.").haloFont(.footnote)
            }
            FocusWeekSummary(history: model.focusHistory, date: referenceDate ?? .now)

            if !model.focusHistory.isEmpty { history }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HaloButton(title: "Begin focus") {
                navigation?.focusSource = "focus-session"
                Task { await model.startFocus(title: title, minutes: minutes) }
            }
            .accessibilityIdentifier("focus-start")
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background {
                if reduceTransparency { palette.surface }
                else { Rectangle().fill(.thinMaterial) }
            }
        }
        .fullScreenCover(isPresented: $activeCover, onDismiss: {
            lastActive = nil
            completed = nil
        }) {
            Group {
                if let completed {
                    FocusCompletionView(session: completed) { activeCover = false }
                } else if let session = model.focus?.isActive == true ? model.focus : lastActive {
                    FocusActiveView(session: session)
                }
            }
            .haloTheme(model.theme)
            .preferredColorScheme(.dark)
            .haloZoomDestination(navigation?.focusSource ?? "focus-session")
            .haloToastHost()
        }
        .onAppear {
            updateSuggestions()
            if let session = model.focus, session.isActive {
                lastActive = session
                activeCover = true
            }
        }
        .onChange(of: model.events) { _, _ in updateSuggestions() }
        .onChange(of: model.habits) { _, _ in updateSuggestions() }
        .onChange(of: model.focus) { old, new in
            if let new, new.isActive {
                completed = nil
                lastActive = new
                activeCover = true
            } else if let old, old.isActive, let new {
                if new.endDate >= old.endDate { completed = new }
                else { activeCover = false }
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
                            Text("\(session.durationMinutes) min").foregroundStyle(palette.ink2)
                        }
                        .haloFont(.footnote)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }

    private func updateSuggestions() {
        let values = model.todayEvents.prefix(2).map(\.title) + model.habits.prefix(1).map(\.title)
        var seen = Set<String>()
        suggestions = values.filter { seen.insert($0).inserted }.map { ($0, $0) }
    }
}

#Preview("Focus · Pearl") {
    FocusView().environment(HaloModel()).haloTheme(ThemeRegistry.theme("pearlHalo"))
}

#Preview("Focus · Gold AX3 Reduced Motion") {
    FocusView().environment(HaloModel()).haloTheme(ThemeRegistry.theme("midnightGold"))
        .environment(\.dynamicTypeSize, .accessibility3)
        .environment(\.haloReduceMotionOverride, true)
}
