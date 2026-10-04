import SwiftUI

struct HaloScreen<Content: View>: View {
    @Environment(\.haloTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder var content: Content
    var body: some View {
        ZStack {
            ThemeBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: HaloTokens.Space.section) { content }
                    .frame(maxWidth: 600).padding(HaloTokens.Space.card).frame(maxWidth: .infinity)
            }
        }.foregroundStyle(Color(hex: theme.palette(scheme).ink))
            .tint(Color(hex: theme.palette(scheme).accentInk))
    }
}
struct SectionTitle: View {
    var title: String
    var subtitle: String?
    var body: some View {
        VStack(alignment: .leading, spacing: HaloTokens.Space.small) {
            Text(LocalizedStringKey(title)).font(HaloTokens.display)
            if let subtitle { Text(LocalizedStringKey(subtitle)).font(.subheadline).foregroundStyle(.secondary) }
        }.padding(.top, HaloTokens.Space.small)
    }
}
