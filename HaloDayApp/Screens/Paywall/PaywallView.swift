import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @Environment(\.haloToasts) private var toasts
    @Environment(\.haloReduceMotion) private var reduceMotion
    @Environment(\.haloReduceTransparency) private var reduceTransparency
    @Environment(\.haloHapticsEnabled) private var haptics
    @Namespace private var planSelection

    @State private var selection = "co.haloday.premium.yearly"
    @State private var appeared = false
    @State private var eligibleTrial = false
    @State private var purchased = false
    @State private var restoring = false
    @State private var showPrivacy = false

    private let features = [
        "All 8 luxury themes, from Champagne Day to Midnight Gold",
        "Advanced widgets: Habit Streak, Focus, and large Home Screen layouts",
        "Unlimited widget presets: switch your look in a tap",
        "Focus sessions on your Lock Screen and Dynamic Island",
        "Event countdowns as Live Activities", "Unlimited rituals with streak history"
    ]

    private var selectedProduct: Product? { model.purchases.products.first { $0.id == selection } }
    private var plans: [PaywallPlan] {
        let year = model.purchases.products.first { $0.id.hasSuffix("yearly") }
        let month = model.purchases.products.first { $0.id.hasSuffix("monthly") }
        let bestValue = year != nil && month != nil && year!.price < month!.price * 12
        return PurchaseService.productIDs.map { id in
            PaywallPlan(id: id, product: model.purchases.products.first { $0.id == id }, bestValue: bestValue && id.hasSuffix("yearly"))
        }
    }

    private var trialDays: Int? {
        guard let period = selectedProduct?.subscription?.introductoryOffer?.period else { return nil }
        switch period.unit {
        case .day: return period.value
        case .week: return period.value * 7
        default: return nil
        }
    }

    private var cta: String {
        guard let product = selectedProduct else { return String(localized: "Continue") }
        if eligibleTrial {
            if let trialDays { return String(localized: "Start \(trialDays)-day free trial") }
            return String(localized: "Start free trial")
        }
        if selection.hasSuffix("lifetime") { return String(localized: "Buy once for \(product.displayPrice)") }
        if selection.hasSuffix("monthly") { return String(localized: "Subscribe for \(product.displayPrice)/month") }
        return String(localized: "Continue with Yearly")
    }

    private var trialCopy: String? {
        guard eligibleTrial, let price = selectedProduct?.displayPrice else { return nil }
        if selection.hasSuffix("monthly") {
            return trialDays.map { String(localized: "Free for \($0) days, then \(price)/month. Cancel anytime.") }
                ?? String(localized: "Free trial, then \(price)/month. Cancel anytime.")
        }
        return trialDays.map { String(localized: "Free for \($0) days, then \(price)/year. Cancel anytime.") }
            ?? String(localized: "Free trial, then \(price)/year. Cancel anytime.")
    }

    var body: some View {
        NavigationStack {
            HaloScreen {
                PaywallHero(events: model.todayEvents, habits: model.habits)
                SectionTitle(
                    title: "Make every glance beautiful.",
                    subtitle: "All themes, advanced widgets, and Live Activities. Your day, at its most beautiful."
                )

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(features.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "sparkle")
                                .foregroundStyle(palette.accentInk)
                                .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? false : appeared)
                            Text(LocalizedStringKey(features[index]))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .haloFont(.subhead)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared || reduceMotion ? 0 : 12)
                        .animation(Motion.resolve(Motion.stagger(index), reduceMotion: reduceMotion), value: appeared)
                    }
                }

                VStack(spacing: 12) {
                    ForEach(plans) { plan in
                        Button {
                            withAnimation(Motion.resolve(Motion.snappy, reduceMotion: reduceMotion)) {
                                selection = plan.id
                            }
                        } label: {
                            PaywallPlanCard(plan: plan, selected: selection == plan.id, namespace: planSelection)
                        }
                        .buttonStyle(PressableStyle())
                        .disabled(model.purchases.isLoading)
                        .accessibilityIdentifier("plan-\(plan.id)")
                        .accessibilityAddTraits(selection == plan.id ? [.isSelected] : [])
                    }
                }
                .accessibilityIdentifier("paywall-plans")

                Text(model.purchases.products.isEmpty
                     ? String(localized: "Purchases are not configured for this build. The free experience is ready to use.")
                     : String(localized: "Subscriptions renew automatically until canceled in App Store Settings. Prices shown are for the selected billing period."))
                    .haloFont(.footnote)
                    .foregroundStyle(palette.ink2)

                if let message = model.purchases.message {
                    Text(message).haloFont(.footnote).foregroundStyle(palette.ink2)
                }
                Text("Your calendar never leaves your iPhone.")
                    .haloFont(.caption).foregroundStyle(palette.ink2)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { purchaseTray }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("paywall-close")
                }
            }
        }
        .onAppear { appeared = true }
        .sensoryFeedback(.selection, trigger: selection) { _, _ in haptics }
        .task(id: selectedProduct?.id) {
            eligibleTrial = false
            guard let subscription = selectedProduct?.subscription,
                  subscription.introductoryOffer?.paymentMode == .freeTrial else { return }
            let eligible = await subscription.isEligibleForIntroOffer
            guard !Task.isCancelled else { return }
            eligibleTrial = eligible
        }
        .sheet(isPresented: $showPrivacy) { privacySheet.haloSheet() }
    }

    private var purchaseTray: some View {
        VStack(spacing: 8) {
            HaloButton(
                title: cta, isLoading: model.purchases.isLoading,
                isSuccess: purchased, emitSuccessFeedback: false
            ) { Task { await purchase() } }
            .disabled(selectedProduct == nil)

            if let trialCopy {
                Text(trialCopy)
                    .haloFont(.footnote)
                    .foregroundStyle(palette.ink2)
                    .multilineTextAlignment(.center)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) { restore; legalLinks }
                VStack(spacing: 4) { restore; legalLinks }
            }
            .haloFont(.footnote)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background {
            if reduceTransparency { palette.surface }
            else { Rectangle().fill(.thinMaterial) }
        }
    }

    private var restore: some View {
        Button("Restore Purchase") {
            Task {
                restoring = true
                await model.purchases.restore()
                restoring = false
                if model.purchases.isPremium {
                    model.persist()
                    dismiss()
                    toasts?.show("Welcome back. Premium is restored.")
                }
            }
        }
        .frame(minHeight: 44)
        .disabled(restoring)
    }

    private var legalLinks: some View {
        HStack(spacing: 20) {
            Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                .frame(minHeight: 44)
            Button("Privacy") { showPrivacy = true }.frame(minHeight: 44)
        }
    }

    private var privacySheet: some View {
        NavigationStack {
            HaloScreen {
                SectionTitle(title: "Privacy")
                Text("Your calendar never leaves your iPhone. Halo Day has no accounts, no tracking, and no servers.")
                    .haloFont(.body)
            }
            .toolbar { Button("Close") { showPrivacy = false } }
        }
    }

    private func purchase() async {
        guard let product = selectedProduct else { return }
        await model.purchases.purchase(product)
        guard model.purchases.isPremium else { return }
        purchased = true
        model.persist()
        try? await Task.sleep(for: .seconds(1.5))
        dismiss()
        toasts?.show("Welcome to Halo Day Premium.")
    }
}

#Preview("Paywall · Light") {
    PaywallView().environment(HaloModel()).haloTheme(ThemeRegistry.theme("pearlHalo"))
}

#Preview("Paywall · Gold AX3 Reduced Motion") {
    PaywallView().environment(HaloModel()).haloTheme(ThemeRegistry.theme("midnightGold"))
        .environment(\.dynamicTypeSize, .accessibility3)
        .environment(\.haloReduceMotionOverride, true)
}
