import SwiftUI

struct OnboardingView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.haloReduceMotion) private var reduceMotion
    @Environment(\.haloHapticsEnabled) private var haptics
    @Environment(\.haloScreenshotMode) private var screenshotMode
    @State private var step = 0
    @State private var direction = 1
    @State private var themeID = "pearlHalo"
    @State private var starter = WidgetType.agenda
    @State private var busy = false
    @State private var success = false
    @State private var finishing = false

    private let titles = [
        "Halo Day", "Your day, at a glance", "Choose your style",
        "Bring in your calendar", "Gentle reminders", "Your first Halo"
    ]
    private let bodies = [
        "Your day, beautifully on display.",
        "Your schedule, rituals and focus time on the Lock Screen. Glance, and go.",
        "Pick a look. You can change it anytime.",
        "Halo Day reads your calendar to show what's next. It stays on your iPhone. Always.",
        "A quiet nudge before events and rituals. Never noisy.",
        "Choose a starting layout. Make it yours in Studio."
    ]

    private var theme: HaloTheme { ThemeRegistry.theme(step < 2 ? "pearlHalo" : themeID) }
    private var secondaryVisible: Bool { step == 3 || step == 4 }

    private var cta: String {
        switch step {
        case 0: String(localized: "Begin")
        case 2: String(localized: "Continue with \(String(localized: String.LocalizationValue(theme.name)))")
        case 3: String(localized: "Connect Calendar")
        case 4: String(localized: "Allow reminders")
        case 5: String(localized: "Save my Halo")
        default: String(localized: "Continue")
        }
    }

    var body: some View {
        ZStack {
            ThemeBackground(breathing: step == 0)
            VStack(spacing: 0) {
                HStack {
                    Button { advance(-1) } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Back")
                    .opacity(step > 0 ? 1 : 0)
                    .disabled(step == 0 || busy)
                    .accessibilityHidden(step == 0)
                    Spacer()
                    Text("\(step + 1) / 6")
                        .haloFont(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 16)

                ScrollView {
                    VStack(spacing: 24) {
                        if step == 0 { HaloWelcomeHero() }
                        else {
                            Text(LocalizedStringKey(titles[step]))
                                .haloFont(.displayL)
                                .multilineTextAlignment(.center)
                        }
                        Text(LocalizedStringKey(bodies[step]))
                            .haloFont(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        pageContent
                    }
                    .frame(maxWidth: 600)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .id(step)
                    .transition(pageTransition)
                }
                .scrollIndicators(.hidden)

                VStack(spacing: 16) {
                    HaloPagerIndicator(total: 6, selection: step)
                    HaloButton(title: cta, isLoading: busy && !success, isSuccess: success) {
                        Task { await next() }
                    }
                    .disabled(finishing || (busy && !success))
                    .accessibilityIdentifier("onboarding-primary")
                    Button("Not now") { advance(1) }
                        .frame(minHeight: 44)
                        .opacity(secondaryVisible ? 1 : 0)
                        .disabled(!secondaryVisible || busy)
                        .accessibilityHidden(!secondaryVisible)
                }
                .padding(20)
            }
        }
        .haloTheme(theme)
        .scaleEffect(finishing && !reduceMotion ? 1.04 : 1)
        .opacity(finishing ? 0 : 1)
        .animation(Motion.resolve(Motion.smooth, reduceMotion: reduceMotion), value: step)
        .animation(Motion.resolve(Motion.smooth, reduceMotion: reduceMotion), value: finishing)
        .sensoryFeedback(.selection, trigger: themeID) { _, _ in haptics }
    }

    @ViewBuilder private var pageContent: some View {
        switch step {
        case 1:
            PhonePreview(
                preset: WidgetPreset(name: "My Halo", widgetType: starter, themeId: themeID),
                events: MockData.events(), habits: MockData.habits, animateSlots: true
            )
            .scaleEffect(0.74)
            .frame(height: 330)
        case 2: OnboardingThemeCarousel(selection: $themeID)
        case 3: PermissionIllustration(calendar: true)
        case 4: PermissionIllustration(calendar: false)
        case 5:
            StarterPresetPicker(selection: $starter, themeID: themeID)
            if theme.isPremium && !model.purchases.isPremium {
                Text("Premium styles can be explored in Studio. Your first Halo starts with Pearl Halo.")
                    .haloFont(.footnote).foregroundStyle(.secondary)
            }
        default: EmptyView()
        }
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: direction > 0 ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: direction > 0 ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private func advance(_ amount: Int) {
        guard !busy else { return }
        direction = amount
        success = false
        withAnimation(Motion.resolve(Motion.smooth, reduceMotion: reduceMotion)) {
            step = min(5, max(0, step + amount))
        }
    }

    private func next() async {
        guard !busy else { return }
        busy = true
        let current = step
        if current == 3 { await model.requestCalendar(); success = model.settings.calendarPermissionGranted }
        if current == 4 { await model.requestNotifications(); success = model.settings.notificationPermissionGranted }
        if success { try? await Task.sleep(for: .milliseconds(550)) }

        if current == 5 {
            let chosen = theme.isPremium && !model.purchases.isPremium ? ThemeRegistry.all[0] : theme
            model.settings.selectedThemeId = chosen.id
            if model.presets.isEmpty {
                _ = model.savePreset(WidgetPreset(name: String(localized: "My first Halo"), widgetType: starter, themeId: chosen.id))
            }
            success = true
            finishing = true
            try? await Task.sleep(for: .milliseconds(350))
            model.settings.hasCompletedOnboarding = true
            if !screenshotMode { model.persist() }
            try? await Task.sleep(for: .milliseconds(350))
            model.showGuide = true
            busy = false
        } else {
            busy = false
            advance(1)
        }
    }
}

#Preview("Onboarding · Light") {
    OnboardingView().environment(HaloModel())
}

#Preview("Onboarding · AX3 Reduced Motion") {
    OnboardingView().environment(HaloModel())
        .environment(\.dynamicTypeSize, .accessibility3)
        .environment(\.haloReduceMotionOverride, true)
}
