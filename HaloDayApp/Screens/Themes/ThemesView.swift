import SwiftUI

struct ThemesView: View {
    @Environment(HaloModel.self) private var model
    var body: some View {
        HaloScreen {
            SectionTitle(title: "Eight ways to glow", subtitle: "A look for every kind of day.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 155))], spacing: HaloTokens.Space.card) {
                ForEach(ThemeRegistry.all) { theme in
                    NavigationLink { ThemeDetailView(theme: theme) } label: {
                        VStack(alignment: .leading, spacing: HaloTokens.Space.row) {
                            Image(systemName: "circle.dotted").font(.system(size: 44, weight: .ultraLight)).foregroundStyle(PaletteResolver.resolve(theme, scheme: .light).accent).frame(maxWidth: .infinity).padding(.vertical, HaloTokens.Space.section)
                            Text(LocalizedStringKey(theme.name)).font(HaloTokens.title)
                            Text(LocalizedStringKey(theme.mood)).font(.caption).frame(minHeight: 36, alignment: .topLeading)
                            if theme.isPremium { PremiumChip() }
                            else { Label("Included", systemImage: "checkmark").font(.caption) }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(HaloTokens.Space.card)
                            .foregroundStyle(PaletteResolver.resolve(theme, scheme: .light).ink)
                            .background(PaletteResolver.resolve(theme, scheme: .light).bg, in: RoundedRectangle(cornerRadius: HaloTokens.Radius.hero, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: HaloTokens.Radius.hero, style: .continuous).stroke(PaletteResolver.resolve(theme, scheme: .light).hairline))
                    }.buttonStyle(.plain)
                }
            }
        }
    }
}
struct ThemeDetailView: View {
    @Environment(HaloModel.self) private var model
    var theme: HaloTheme
    var body: some View {
        HaloScreen {
            SectionTitle(title: theme.name, subtitle: theme.mood)
            if theme.isPremium { PremiumChip(preview: !model.purchases.isPremium) }
            PhonePreview(preset: WidgetPreset(name: theme.name, themeId: theme.id), events: model.todayEvents, habits: model.habits, focus: model.focus, countdown: model.countdowns.first, sample: model.isSample).frame(maxWidth: .infinity)
            HaloCard {
                VStack(alignment: .leading, spacing: HaloTokens.Space.small) {
                    Text("Your day, beautifully on display.").font(HaloTokens.title)
                    Text("Full theme color in the app, Home Screen widgets and Live Activities. Lock Screen widgets follow your wallpaper.").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Button(model.theme.id == theme.id ? "Applied" : "Apply theme") { model.applyTheme(theme) }.buttonStyle(HaloButtonStyle())
        }.environment(\.haloTheme, theme).preferredColorScheme(theme.darkOnly ? .dark : nil)
    }
}
