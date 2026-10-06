import SwiftUI
import EventKit

@main
struct HaloDayApp: App {
    private let launch: HaloLaunchConfiguration
    @State private var model: HaloModel
    @Environment(\.scenePhase) private var phase

    init() {
        let configuration = HaloLaunchConfiguration.current
        launch = configuration
        _model = State(initialValue: configuration.makeModel())
    }

    var body: some Scene {
        WindowGroup {
            ThemedRoot(model: model, launch: launch)
                .task {
                    guard !launch.isScreenshotMode else { return }
                    await model.purchases.start()
                    await model.refresh()
                }
                .onChange(of: phase) { _, value in
                    guard !launch.isScreenshotMode, value == .active else { return }
                    Task { await model.refresh() }
                }
                .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
                    guard !launch.isScreenshotMode else { return }
                    Task { await model.refresh() }
                }
                .onOpenURL { model.route($0) }
        }
    }
}

private struct ThemedRoot: View {
    var model: HaloModel
    var launch: HaloLaunchConfiguration
    @Environment(\.colorScheme) private var scheme
    @Environment(\.haloReduceMotion) private var reduceMotion
    @State private var toasts = HaloToastCenter()

    var body: some View {
        let palette = PaletteResolver.resolve(model.theme, scheme: scheme)
        RootView()
            .environment(model)
            .environment(\.haloTheme, model.theme)
            .environment(\.palette, palette)
            .environment(\.haloHapticsEnabled, model.settings.haptics)
            .environment(\.haloReferenceDate, launch.referenceDate)
            .environment(\.haloScreenshotMode, launch.isScreenshotMode)
            .environment(\.haloScreenshotScreen, launch.screen)
            .environment(\.haloReduceMotionOverride, launch.reduceMotion)
            .environment(\.haloReduceTransparencyOverride, launch.reduceTransparency)
            .environment(toasts)
            .environment(\.haloToasts, toasts)
            .tint(palette.accentInk)
            .preferredColorScheme(preferredColorScheme)
            .animation(Motion.resolve(Motion.gentle, reduceMotion: reduceMotion), value: model.theme.id)
            .animation(Motion.resolve(Motion.smooth, reduceMotion: reduceMotion), value: model.purchases.isPremium)
            .haloToastHost(visible: !model.showPaywall && !model.showSettings && !model.showGuide && model.selectedEvent == nil && !(model.focus?.isActive == true && model.tab == 4))
            .onChange(of: model.purchases.isPremium) { old, new in
                if !old && new && !model.showPaywall { toasts.show("Welcome to Halo Day Premium.") }
            }
            .sensoryFeedback(.success, trigger: model.purchases.isPremium) { _, new in new && model.settings.haptics }
            .sensoryFeedback(.success, trigger: model.theme.id) { _, _ in model.settings.haptics }
            .sensoryFeedback(.success, trigger: model.completedHabits) { old, new in
                new > old && model.settings.haptics
            }
            .sensoryFeedback(.selection, trigger: model.selectedEvent?.id) { _, new in
                new != nil && model.settings.haptics
            }
    }

    private var preferredColorScheme: ColorScheme? {
        if launch.colorScheme == "dark" || model.theme.darkOnly { return .dark }
        if launch.colorScheme == "light" { return .light }
        return nil
    }
}

struct RootView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.haloReduceMotion) private var reduceMotion
    @Namespace private var namespace
    @State private var navigation = HaloNavigationState()
    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.tab) {
            NavigationStack { TodayView() }.haloTabMotion(selected: model.tab == 0)
                .tabItem { tabLabel("Today", symbol: "sun.horizon", tab: 0) }.tag(0)
            NavigationStack { CalendarView() }.haloTabMotion(selected: model.tab == 1)
                .tabItem { tabLabel("Calendar", symbol: "calendar", tab: 1) }.tag(1)
            NavigationStack { StudioView() }.haloTabMotion(selected: model.tab == 2)
                .tabItem { tabLabel("Studio", symbol: "square.on.square.dashed", tab: 2) }.tag(2)
            NavigationStack { RitualsView() }.haloTabMotion(selected: model.tab == 3)
                .tabItem { tabLabel("Rituals", symbol: "circle.dashed.inset.filled", tab: 3) }.tag(3)
            NavigationStack { FocusView() }.haloTabMotion(selected: model.tab == 4)
                .tabItem { tabLabel("Focus", symbol: "timer", tab: 4) }.tag(4)
        }
        .fullScreenCover(isPresented: Binding(get: { !model.settings.hasCompletedOnboarding }, set: { _ in })) { OnboardingView() }
        .sheet(isPresented: $model.showPaywall) { PaywallView().haloSheet([.large]) }
        .sheet(isPresented: $model.showSettings) { NavigationStack { SettingsView() }.haloSheet([.large]) }
        .sheet(isPresented: $model.showGuide) { NavigationStack { WidgetGuideView() }.haloSheet([.large]) }
        .sheet(item: $model.selectedEvent) { event in
            NavigationStack { EventDetailView(event: event) }
                .haloZoomDestination(navigation.eventSource)
                .haloSheet()
        }
        .alert("Halo Day", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("OK") { model.error = nil } } message: { Text(model.error ?? "") }
        .environment(\.haloNamespace, namespace)
        .environment(\.haloNavigation, navigation)
        .sensoryFeedback(.selection, trigger: model.tab) { _, _ in model.settings.haptics }
    }

    private func tabLabel(_ title: String, symbol: String, tab: Int) -> some View {
        Label {
            Text(LocalizedStringKey(title))
        } icon: {
            Image(systemName: symbol).symbolEffect(.bounce, value: reduceMotion ? false : model.tab == tab)
        }
        .accessibilityIdentifier("tab-\(tab)")
    }
}
