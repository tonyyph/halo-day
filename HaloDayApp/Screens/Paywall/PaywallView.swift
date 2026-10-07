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
        name = id.hasSuffix("yearly") ? String(localized: "Yearly") : id.hasSuffix("monthly") ? String(localized: "Monthly") : String(localized: "Lifetime")
        price = product?.displayPrice ?? String(localized: "Coming soon")
        period = id.hasSuffix("yearly") ? String(localized: "per year") : id.hasSuffix("monthly") ? String(localized: "per month") : String(localized: "once")
        self.bestValue = bestValue
        monthlyEquivalent = id.hasSuffix("yearly") ? product.map { ($0.price / 12).formatted($0.priceFormatStyle) } : nil
    }
}

/// v2 paywall: the Premium skies cycle behind an Orbit that changes style with them. Prices, periods and trials
/// come only from StoreKit; with no products, plans show placeholders and purchase stays disabled.
struct PaywallView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.haloToasts) private var toasts
    @Environment(\.haloReduceMotion) private var reduceMotion
    @Environment(\.haloHapticsEnabled) private var haptics
    @Environment(\.haloReferenceDate) private var referenceDate

    @State private var selection = "co.haloday.premium.yearly"
    @State private var eligibleTrial = false
    @State private var purchased = false
    @State private var restoring = false
    @State private var showPrivacy = false
    @State private var skyIndex = 0

    private let skies: [SkyID] = [.aurora, .instrument, .goldenHour, .mist]
    private let benefits: [(String, LocalizedStringKey)] = [
        ("sparkles", "Every sky — Instrument, Aurora, Golden Hour and Mist"),
        ("circle.grid.cross", "Rhythm and Rituals widgets, and unlimited setups"),
        ("timer", "Focus and event countdowns on your Lock Screen and Dynamic Island"),
        ("infinity", "Unlimited rituals and countdowns")
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
        let now = referenceDate ?? .now
        let skyID = skies[skyIndex % skies.count]
        let sky = SkyEngine.state(sky: skyID, at: now, coordinate: model.skyCoordinate)
        NavigationStack {
            ZStack {
                SkyBackground(state: sky)
                    .id(skyID)
                    .transition(.opacity)
                VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Space.xl) {
                        ZStack {
                            OrbitCanvas(content: OrbitContent(layout: OrbitLayout(day: now, events: model.events(on: now)),
                                                              beads: DaySceneBuilder.beads(for: model.habits, on: now),
                                                              nowHour: OrbitGeometry.hours(of: now, calendar: .current)),
                                        sky: sky, style: skyID.orbitStyle)
                            VStack(spacing: 2) {
                                Text(skyID.title).font(DS.Typeface.title(20, relativeTo: .headline))
                                Text(skyID.mood).font(DS.Typeface.moment(13, relativeTo: .caption)).opacity(SkyEngine.secondaryOpacity)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: 140)
                            // The ring is a fixed-size picture; its caption must fit inside it.
                            .dynamicTypeSize(...DynamicTypeSize.large)
                        }
                        .frame(width: 180, height: 180)
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                        Text("Every sky. Every ritual. Your whole day.")
                            .font(DS.Typeface.display(30, relativeTo: .largeTitle))
                            .fixedSize(horizontal: false, vertical: true)
                        VStack(alignment: .leading, spacing: DS.Space.m) {
                            ForEach(benefits.indices, id: \.self) { index in
                                HStack(alignment: .top, spacing: DS.Space.m) {
                                    Image(systemName: benefits[index].0).frame(width: 24).accessibilityHidden(true)
                                    Text(benefits[index].1).fixedSize(horizontal: false, vertical: true)
                                }
                                .font(.subheadline)
                            }
                        }
                        VStack(spacing: DS.Space.s) {
                            ForEach(plans) { plan in planRow(plan, sky: sky) }
                        }
                        .accessibilityIdentifier("paywall-plans")
                        Text(model.purchases.products.isEmpty
                             ? String(localized: "Purchases are not configured for this build. The free experience is ready to use.")
                             : String(localized: "Subscriptions renew automatically until canceled in App Store Settings. Prices shown are for the selected billing period."))
                            .font(.footnote).opacity(SkyEngine.secondaryOpacity)
                    }
                    .padding(DS.Space.xl)
                }
                .scrollIndicators(.hidden)
                // Below the scroll view, not over it: plan rows never sit behind the purchase button.
                purchaseTray(sky)
                }
            }
            .foregroundStyle(sky.inkColor.color)
            .tint(sky.inkColor.color)
            .environment(\.colorScheme, sky.ink == .light ? .dark : .light)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                        .accessibilityLabel("Close")
                        .accessibilityIdentifier("paywall-close")
                }
            }
        }
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 1.2)) { skyIndex += 1 }
            }
        }
        .sensoryFeedback(.selection, trigger: selection) { _, _ in haptics }
        .task(id: selectedProduct?.id) {
            eligibleTrial = false
            guard let subscription = selectedProduct?.subscription,
                  subscription.introductoryOffer?.paymentMode == .freeTrial else { return }
            let eligible = await subscription.isEligibleForIntroOffer
            guard !Task.isCancelled else { return }
            eligibleTrial = eligible
        }
        .sheet(isPresented: $showPrivacy) { privacySheet }
    }

    private func planRow(_ plan: PaywallPlan, sky: SkyState) -> some View {
        let selected = selection == plan.id
        return Button { selection = plan.id } label: {
            HStack(spacing: DS.Space.m) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle").font(.title3).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DS.Space.s) {
                        Text(plan.name).font(.headline)
                        if plan.bestValue {
                            Text("Best value").font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(OrbitPalette.ritualColor(sky: sky).opacity(0.35)))
                        }
                    }
                    if let monthly = plan.monthlyEquivalent {
                        Text("\(monthly) per month").font(.caption).opacity(SkyEngine.secondaryOpacity)
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.price).font(.headline.monospacedDigit())
                    Text(plan.period).font(.caption).opacity(SkyEngine.secondaryOpacity)
                }
            }
            .padding(DS.Space.l)
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.glass, style: .continuous))
            .haloGlass(RoundedRectangle(cornerRadius: DS.Radius.glass, style: .continuous), tint: sky.mid.color)
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.glass, style: .continuous).strokeBorder(Color.primary.opacity(selected ? 0.55 : 0), lineWidth: 2))
        }
        .buttonStyle(.plain)
        .disabled(model.purchases.isLoading)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("plan-\(plan.id)")
    }

    private func purchaseTray(_ sky: SkyState) -> some View {
        VStack(spacing: DS.Space.s) {
            Button { Task { await purchase() } } label: {
                HStack {
                    if model.purchases.isLoading { ProgressView() }
                    if purchased { Image(systemName: "checkmark") }
                    Text(cta).font(.headline)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(GlassPillStyle(sky: sky))
            .disabled(selectedProduct == nil || model.purchases.isLoading)
            .accessibilityIdentifier("paywall-purchase")
            // Purchase and restore outcomes sit next to the buttons that caused them, never below the fold.
            if let message = model.purchases.message {
                Text(message).font(.footnote.weight(.semibold)).multilineTextAlignment(.center)
                    .accessibilityIdentifier("paywall-message")
            }
            if let trialCopy {
                Text(trialCopy).font(.footnote).opacity(SkyEngine.secondaryOpacity).multilineTextAlignment(.center)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: DS.Space.l) { restore; legalLinks }
                VStack(spacing: DS.Space.xs) { restore; legalLinks }
            }
            .font(.footnote)
        }
        .padding(.horizontal, DS.Space.xl)
        .padding(.top, DS.Space.m)
        .padding(.bottom, DS.Space.s)
        .overlay(alignment: .top) { Rectangle().fill(Color.primary.opacity(0.12)).frame(height: 0.5) }
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
        .accessibilityIdentifier("paywall-restore")
    }

    private var legalLinks: some View {
        HStack(spacing: DS.Space.l) {
            Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                .frame(minHeight: 44)
            Button("Privacy") { showPrivacy = true }.frame(minHeight: 44)
        }
    }

    private var privacySheet: some View {
        NavigationStack {
            SkyScreen { _, _ in
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Space.m) {
                        Text("Your calendar never leaves your iPhone. Halo Day has no accounts, no tracking, and no servers.")
                        Text("Location, if you turn it on, is rounded to about 10 km and stays on this iPhone. Wallpapers are added to Photos without reading your library.")
                            .opacity(SkyEngine.secondaryOpacity)
                    }
                    .padding(DS.Space.xl)
                }
            }
            .navigationTitle("Privacy")
            .toolbar { Button("Close") { showPrivacy = false } }
        }
        .presentationDetents([.medium])
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
