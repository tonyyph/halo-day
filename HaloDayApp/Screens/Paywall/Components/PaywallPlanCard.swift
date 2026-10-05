import SwiftUI
import StoreKit

struct PaywallPlan: Identifiable {
    let id: String
    let product: Product?
    let name: String
    let price: String
    let period: String
    let bestValue: Bool
    let monthlyEquivalent: String?

    init(id: String, product: Product?, bestValue: Bool = false) {
        self.id = id
        self.product = product
        name = id.hasSuffix("yearly") ? "Yearly" : id.hasSuffix("monthly") ? "Monthly" : "Lifetime"
        price = product?.displayPrice ?? String(localized: "Coming soon")
        period = id.hasSuffix("yearly") ? "per year" : id.hasSuffix("monthly") ? "per month" : "once"
        self.bestValue = bestValue
        monthlyEquivalent = id.hasSuffix("yearly") ? product.map { ($0.price / 12).formatted($0.priceFormatStyle) } : nil
    }
}

struct PaywallPlanCard: View {
    var plan: PaywallPlan
    var selected: Bool
    var namespace: Namespace.ID
    @Environment(\.palette) private var palette
    @Environment(\.haloReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicType

    var body: some View {
        let layout = dynamicType.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        layout {
            HStack(spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(palette.accentInk)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 5) {
                    Text(LocalizedStringKey(plan.name)).haloFont(.headline)
                    if plan.bestValue {
                        Text("Best value")
                            .captionUpper()
                            .foregroundStyle(palette.accentInk)
                    }
                    if plan.id.hasSuffix("lifetime") {
                        Text("Pay once. Yours forever.").haloFont(.caption).foregroundStyle(palette.ink2)
                    }
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: dynamicType.isAccessibilitySize ? .leading : .trailing, spacing: 3) {
                Text(plan.price)
                    .haloFont(.displayS)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if plan.product != nil {
                    Text(LocalizedStringKey(plan.period)).haloFont(.caption).foregroundStyle(palette.ink2)
                }
                if let equivalent = plan.monthlyEquivalent {
                    Text("\(equivalent)/month").haloFont(.caption).foregroundStyle(palette.ink2)
                }
            }
        }
        .padding(18)
        .foregroundStyle(palette.ink)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(palette.hairline, lineWidth: 0.5)
            if selected {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(palette.accent, lineWidth: 1.5)
                    .matchedGeometryEffect(id: "plan", in: namespace, properties: reduceMotion ? [] : .frame)
            }
        }
        .scaleEffect(selected && !reduceMotion ? 1.02 : 1)
        .shadow(color: palette.shadowTint.opacity(selected ? 0.08 : 0), radius: 16, y: 5)
    }
}

#Preview("Plan · Ruby Dark") {
    @Previewable @Namespace var namespace
    DesignPreview(themeID: "rubyGlass", scheme: .dark) {
        PaywallPlanCard(plan: PaywallPlan(id: "co.haloday.premium.yearly", product: nil), selected: true, namespace: namespace)
    }
}

#Preview("Plan · Champagne AX3") {
    @Previewable @Namespace var namespace
    DesignPreview(themeID: "champagneDay", accessibility: true, reduceMotion: true) {
        PaywallPlanCard(plan: PaywallPlan(id: "co.haloday.premium.lifetime", product: nil), selected: true, namespace: namespace)
    }
}
