import SwiftUI

struct SettingsGlyph: View {
    var symbol: String
    @Environment(\.palette) private var palette

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(palette.accentInk)
            .frame(width: 28, height: 28)
            .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct SettingsLabel: View {
    var title: String
    var symbol: String

    var body: some View {
        HStack(spacing: 12) {
            SettingsGlyph(symbol: symbol)
            Text(LocalizedStringKey(title))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 36)
    }
}

struct PremiumStatusRow: View {
    var premium: Bool
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "sparkle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(palette.accentInk)
                .frame(width: 52, height: 52)
                .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text(premium ? String(localized: "Halo Day Premium") : String(localized: "Upgrade to Premium"))
                    .haloFont(.displayS)
                Text("Make every glance beautiful.")
                    .haloFont(.footnote)
                    .foregroundStyle(palette.ink2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(palette.ink3)
        }
        .padding(.vertical, 12)
        .overlay {
            if !reduceMotion {
                GeometryReader { proxy in
                    LinearGradient(colors: [.clear, palette.accentSoft.opacity(0.2), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: proxy.size.width * 0.6)
                        .phaseAnimator([false, true], trigger: appeared) { view, phase in
                            view.offset(x: phase ? proxy.size.width : -proxy.size.width)
                        } animation: { _ in Motion.shimmer }
                }
                .clipped()
                .allowsHitTesting(false)
            }
        }
        .onAppear { appeared = true }
    }
}
