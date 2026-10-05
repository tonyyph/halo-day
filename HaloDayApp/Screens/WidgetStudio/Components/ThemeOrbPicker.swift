import SwiftUI

struct ThemeOrbPicker: View {
    @Binding var selection: String

    @Environment(\.palette) private var palette
    @Environment(\.haloHapticsEnabled) private var haptics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                ForEach(ThemeRegistry.all) { theme in
                    let colors = PaletteResolver.resolve(theme, scheme: .light)
                    Button {
                        withAnimation(Motion.resolve(Motion.gentle, reduceMotion: reduceMotion)) {
                            selection = theme.id
                        }
                    } label: {
                        Circle()
                            .fill(AngularGradient(colors: [colors.bg, colors.accent, colors.bg], center: .center))
                            .frame(width: 42, height: 42)
                            .overlay {
                                Circle()
                                    .stroke(selection == theme.id ? palette.accent : .clear, lineWidth: 2)
                                    .padding(-4)
                            }
                            .overlay(alignment: .bottomTrailing) {
                                if theme.isPremium {
                                    Image(systemName: "sparkle")
                                        .font(.system(size: 8))
                                        .foregroundStyle(palette.accentOn)
                                        .padding(3)
                                        .background(palette.accent, in: Circle())
                                }
                            }
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(Text(LocalizedStringKey(theme.name)))
                    .accessibilityAddTraits(selection == theme.id ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 5)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: selection) { _, _ in haptics }
    }
}
