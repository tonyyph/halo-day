import SwiftUI

struct OnboardingView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var themeID = "pearlHalo"
    @State private var starter = WidgetType.agenda
    @State private var busy = false
    private let titles = ["Halo Day", "Your day, at a glance", "Choose your style", "Bring in your calendar", "Gentle reminders", "Your first Halo"]
    private let bodies = ["Your day, beautifully on display.", "Your schedule, rituals and focus time on the Lock Screen. Glance, and go.", "Pick a look. You can change it anytime.", "Halo Day reads your calendar to show what's next. It stays on your iPhone. Always.", "A quiet nudge before events and rituals. Never noisy.", "Choose a starting layout. Make it yours in Studio."]
    private var previewTheme: HaloTheme { ThemeRegistry.theme(themeID) }
    var body: some View {
        ZStack {
            ThemeBackground()
            VStack(spacing: HaloTokens.Space.card) {
                HStack {
                    if step > 0 { Button { advance(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("Back") }
                    Spacer()
                    Text("\(step + 1) / 6").font(.caption).foregroundStyle(.secondary)
                }.padding(.horizontal, HaloTokens.Space.card)
                ScrollView {
                    VStack(spacing: HaloTokens.Space.section) {
                        if step == 0 {
                            Image(systemName: "circle.dotted").font(.system(size: 120, weight: .ultraLight)).foregroundStyle(.tint).padding(.vertical, HaloTokens.Space.onboarding)
                        }
                        Text(LocalizedStringKey(titles[step])).font(HaloTokens.display).multilineTextAlignment(.center)
                        Text(LocalizedStringKey(bodies[step])).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        if [1, 5].contains(step) {
                            PhonePreview(preset: WidgetPreset(name: "My Halo", widgetType: starter, themeId: themeID), events: MockData.events(), habits: MockData.habits, focus: nil, countdown: nil)
                        }
                        if step == 2 {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145))], spacing: HaloTokens.Space.row) {
                                ForEach(ThemeRegistry.all) { theme in
                                    Button { themeID = theme.id; model.haptic() } label: {
                                        VStack(alignment: .leading, spacing: HaloTokens.Space.row) {
                                            Image(systemName: "circle.dotted").font(.largeTitle).foregroundStyle(PaletteResolver.resolve(theme, scheme: .light).accent)
                                            Text(LocalizedStringKey(theme.name)).font(HaloTokens.title)
                                            if theme.isPremium { PremiumChip(preview: true) }
                                            if theme.id == themeID { Image(systemName: "checkmark.circle.fill") }
                                        }.frame(maxWidth: .infinity, minHeight: 130, alignment: .leading).padding(HaloTokens.Space.card)
                                            .foregroundStyle(PaletteResolver.resolve(theme, scheme: .light).ink).background(PaletteResolver.resolve(theme, scheme: .light).bg, in: RoundedRectangle(cornerRadius: HaloTokens.Radius.card, style: .continuous))
                                            .overlay(RoundedRectangle(cornerRadius: HaloTokens.Radius.card, style: .continuous).stroke(PaletteResolver.resolve(theme, scheme: .light).hairline, lineWidth: theme.id == themeID ? 3 : 1))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                        if step == 3 {
                            HaloCard { ForEach(MockData.events().prefix(2)) { AgendaRow(event: $0) } }
                            Label("Your calendar never leaves your iPhone.", systemImage: "lock.fill").font(.caption)
                        }
                        if step == 4 {
                            HaloCard { Label("Design review · in 10 minutes", systemImage: "calendar.badge.clock").font(.headline) }
                            HaloCard { Label("A little space to focus", systemImage: "timer").font(.headline) }
                        }
                        if step == 5 {
                            Picker("Starter layout", selection: $starter) { Text("Agenda").tag(WidgetType.agenda); Text("Ritual").tag(WidgetType.ritual); Text("Minimal").tag(WidgetType.month) }.pickerStyle(.segmented)
                            if previewTheme.isPremium {
                                Text("Premium styles can be explored in Studio. Your first Halo starts with Pearl Halo.").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }.frame(maxWidth: 600).padding(HaloTokens.Space.card).frame(maxWidth: .infinity)
                }
                HStack(spacing: 6) { ForEach(0..<6) { index in Capsule().fill(.primary.opacity(index == step ? 1 : 0.2)).frame(width: index == step ? 18 : 6, height: 6) } }.accessibilityHidden(true)
                Button(cta) { Task { await next() } }.buttonStyle(HaloButtonStyle()).disabled(busy).padding(.horizontal, HaloTokens.Space.card)
                if step == 3 || step == 4 { Button("Not now") { advance(1) }.frame(minHeight: 44) }
            }.padding(.bottom, HaloTokens.Space.card)
        }.environment(\.haloTheme, step < 2 ? ThemeRegistry.all[0] : previewTheme)
            .tint(PaletteResolver.resolve(previewTheme, scheme: previewTheme.darkOnly ? .dark : .light).accentInk).preferredColorScheme(previewTheme.darkOnly ? .dark : nil)
    }
    private var cta: String {
        switch step { case 0: String(localized: "Begin"); case 3: String(localized: "Connect Calendar"); case 4: String(localized: "Allow reminders"); case 5: String(localized: "Save my Halo"); default: String(localized: "Continue") }
    }
    private func advance(_ amount: Int) { withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) { step += amount } }
    private func next() async {
        busy = true; defer { busy = false }
        if step == 3 { await model.requestCalendar() }
        if step == 4 { await model.requestNotifications() }
        if step == 5 {
            let chosen = previewTheme.isPremium && !model.purchases.isPremium ? ThemeRegistry.all[0] : previewTheme
            model.settings.selectedThemeId = chosen.id
            if model.presets.isEmpty { _ = model.savePreset(WidgetPreset(name: "My first Halo", widgetType: starter, themeId: chosen.id)) }
            model.settings.hasCompletedOnboarding = true; model.persist(); model.showGuide = true
        } else { advance(1) }
    }
}
