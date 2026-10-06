import SwiftUI
import EventKit

@main
struct HaloDayApp: App {
    private let launch: HaloLaunchConfiguration
    @State private var model: HaloModel
    @Environment(\.scenePhase) private var phase

    init() {
        HaloFonts.registerIfNeeded()
        let configuration = HaloLaunchConfiguration.current
        launch = configuration
        _model = State(initialValue: configuration.makeModel())
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if launch.skyLab {
                SkyLabView(minutes: launch.skyLabMinutes ?? 605,
                           sky: launch.skyLabSky.flatMap(SkyID.init(rawValue:)) ?? .livingSky,
                           place: launch.skyLabPlace.flatMap(SkyLabPlace.init(rawValue:)) ?? .hanoi,
                           season: launch.skyLabSeason.flatMap(SkyLabSeason.init(rawValue:)) ?? .october)
            } else {
                app
            }
            #else
            app
            #endif
        }
    }

    private var app: some View {
        ThemedRoot(model: model, launch: launch)
            .task {
                guard !launch.isScreenshotMode else { return }
                await model.purchases.start()
                await model.refresh()
                model.presentRunningFocus()
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
            .haloToastHost(visible: !model.showPaywall && !model.showSettings && !model.showGuide && model.selectedEvent == nil && !model.showFocus)
            .onChange(of: model.purchases.isPremium) { old, new in
                if !old && new && !model.showPaywall { toasts.show("Welcome to Halo Day Premium.") }
            }
            .sensoryFeedback(.success, trigger: model.purchases.isPremium) { _, new in new && model.settings.haptics }
            .sensoryFeedback(.success, trigger: model.theme.id) { _, _ in model.settings.haptics }
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
            DayView()
                .tabItem { tabLabel("Day", symbol: "sun.horizon", tab: .day, index: 0) }.tag(AppTab.day)
            NavigationStack { StudioView() }.haloTabMotion(selected: model.tab == .studio)
                .tabItem { tabLabel("Studio", symbol: "square.on.square.dashed", tab: .studio, index: 1) }.tag(AppTab.studio)
            NavigationStack { YouView() }
            .haloTabMotion(selected: model.tab == .you)
            .tabItem { tabLabel("You", symbol: "person.crop.circle", tab: .you, index: 2) }.tag(AppTab.you)
        }
        .fullScreenCover(isPresented: Binding(get: { !model.settings.hasCompletedOnboarding }, set: { _ in })) { OnboardingView() }
        .sheet(isPresented: $model.showPaywall) { PaywallView().haloSheet([.large]) }
        .sheet(isPresented: $model.showSettings) { NavigationStack { SettingsView() }.haloSheet([.large]) }
        .sheet(isPresented: $model.showGuide) { NavigationStack { WidgetGuideView() }.haloSheet([.large]) }
        .sheet(item: $model.selectedEvent) { event in DayEventSheet(event: event) }
        .alert("Halo Day", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("OK") { model.error = nil } } message: { Text(model.error ?? "") }
        .environment(\.haloNamespace, namespace)
        .environment(\.haloNavigation, navigation)
        .sensoryFeedback(.selection, trigger: model.tab) { _, _ in model.settings.haptics }
    }

    private func tabLabel(_ title: String, symbol: String, tab: AppTab, index: Int) -> some View {
        Label {
            Text(LocalizedStringKey(title))
        } icon: {
            Image(systemName: symbol).symbolEffect(.bounce, value: reduceMotion ? false : model.tab == tab)
        }
        .accessibilityIdentifier("tab-\(index)")
    }
}
