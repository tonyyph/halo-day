import SwiftUI
import EventKit

@main
struct HaloDayApp: App {
    @State private var model = HaloModel()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            RootView().environment(model).environment(\.haloTheme, model.theme)
                .tint(Color(hex: model.theme.light.accentInk))
                .preferredColorScheme(model.theme.darkOnly ? .dark : nil)
                .task { await model.purchases.start(); await model.refresh() }
                .onChange(of: phase) { _, value in if value == .active { Task { await model.refresh() } } }
                .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in Task { await model.refresh() } }
                .onOpenURL { model.route($0) }
        }
    }
}

struct RootView: View {
    @Environment(HaloModel.self) private var model
    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.tab) {
            NavigationStack { TodayView() }.tabItem { Label("Today", systemImage: "sun.horizon") }.tag(0)
            NavigationStack { CalendarView() }.tabItem { Label("Calendar", systemImage: "calendar") }.tag(1)
            NavigationStack { StudioView() }.tabItem { Label("Studio", systemImage: "square.on.square.dashed") }.tag(2)
            NavigationStack { RitualsView() }.tabItem { Label("Rituals", systemImage: "circle.dashed.inset.filled") }.tag(3)
            NavigationStack { FocusView() }.tabItem { Label("Focus", systemImage: "timer") }.tag(4)
        }
        .fullScreenCover(isPresented: Binding(get: { !model.settings.hasCompletedOnboarding }, set: { _ in })) { OnboardingView() }
        .sheet(isPresented: $model.showPaywall) { PaywallView() }
        .sheet(isPresented: $model.showSettings) { NavigationStack { SettingsView() } }
        .sheet(isPresented: $model.showGuide) { NavigationStack { WidgetGuideView() } }
        .sheet(item: $model.selectedEvent) { event in NavigationStack { EventDetailView(event: event) } }
        .alert("Halo Day", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("OK") { model.error = nil } } message: { Text(model.error ?? "") }
    }
}
