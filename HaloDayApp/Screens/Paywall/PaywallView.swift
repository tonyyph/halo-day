import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(HaloModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var selection = "co.haloday.premium.yearly"
    private var selectedProduct: Product? { model.purchases.products.first { $0.id == selection } }
    var body: some View {
        NavigationStack {
            HaloScreen {
                Image(systemName: "circle.dotted").font(.system(size: 64, weight: .ultraLight)).foregroundStyle(.tint).frame(maxWidth: .infinity).padding(.top, HaloTokens.Space.section)
                SectionTitle(title: "Make your iPhone feel personal again.", subtitle: "Unlock luxury widgets, themes, Live Activities, and unlimited presets.")
                HaloCard {
                    VStack(alignment: .leading, spacing: HaloTokens.Space.card) {
                        Label("All 8 luxury themes", systemImage: "paintpalette")
                        Label("Advanced Home Screen widgets", systemImage: "square.grid.2x2")
                        Label("Unlimited widget presets", systemImage: "square.on.square")
                        Label("Focus on your Lock Screen and Dynamic Island", systemImage: "timer")
                        Label("Event countdown Live Activities", systemImage: "calendar.badge.clock")
                        Label("Unlimited rituals", systemImage: "leaf")
                    }.font(.subheadline)
                }
                ForEach(PurchaseService.productIDs, id: \.self) { id in
                    let product = model.purchases.products.first { $0.id == id }
                    Button { selection = id } label: {
                        HaloCard(hero: selection == id) {
                            HStack {
                                Image(systemName: selection == id ? "largecircle.fill.circle" : "circle").foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: HaloTokens.Space.tiny) {
                                    Text(id.hasSuffix("yearly") ? "Yearly" : id.hasSuffix("monthly") ? "Monthly" : "Lifetime").font(.headline)
                                    if id.hasSuffix("lifetime") { Text("Pay once. Yours forever.").font(.caption).foregroundStyle(.secondary) }
                                }
                                Spacer()
                                Text(product?.displayPrice ?? String(localized: "Coming soon")).font(.headline)
                            }
                        }
                    }.buttonStyle(.plain)
                }
                if model.purchases.products.isEmpty {
                    Text("Purchases are not configured for this build. The free experience is ready to use.").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Subscriptions renew automatically until canceled in App Store Settings. Prices shown are for the selected billing period.").font(.caption).foregroundStyle(.secondary)
                }
                Button("Continue") { if let product = selectedProduct { Task { await model.purchases.purchase(product); if model.purchases.isPremium { model.persist(); dismiss() } } } }.buttonStyle(HaloButtonStyle()).disabled(selectedProduct == nil || model.purchases.isLoading)
                Button("Restore purchases") { Task { await model.purchases.restore(); if model.purchases.isPremium { model.persist(); dismiss() } } }.frame(maxWidth: .infinity, minHeight: 44)
                if let message = model.purchases.message { Text(message).font(.caption).foregroundStyle(.secondary) }
                Text("Your calendar never leaves your iPhone.").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }.toolbar { ToolbarItem(placement: .topBarTrailing) { Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Close") } }
        }
    }
}
